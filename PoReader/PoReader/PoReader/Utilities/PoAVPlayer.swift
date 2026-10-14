import UIKit
import AVFoundation

@MainActor
protocol PoAVPlayerDelegate: AnyObject {
    func avplayerPrepared(_ player: PoAVPlayer)
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: PoAVPlayer.PlaybackStatus)
    func avplayer(_ player: PoAVPlayer, loadedTimeRange range: CMTimeRange)
    func avplayer(_ player: PoAVPlayer, loadStateChanged state: PoAVPlayer.MediaLoadState)
    func avplayer(_ player: PoAVPlayer, periodicallyInvoke time: CMTime)
}

extension PoAVPlayerDelegate {
    func avplayerPrepared(_ player: PoAVPlayer) {}
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: PoAVPlayer.PlaybackStatus) {}
    func avplayer(_ player: PoAVPlayer, loadedTimeRange range: CMTimeRange) {}
    func avplayer(_ player: PoAVPlayer, loadStateChanged state: PoAVPlayer.MediaLoadState) {}
    func avplayer(_ player: PoAVPlayer, periodicallyInvoke time: CMTime) {}
}

extension PoAVPlayer {
    enum AVPlayerError: Error, Equatable {
        case playbackFailed(Error?)
        case resourceLoadFailed(Error?)
        case audioSessionFailed(Error)

        // Compare error categories and codes. Repeated error events are delivered
        // explicitly by fail(), without breaking Equatable's reflexivity.
        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            let errors: (Error?, Error?)
            switch (lhs, rhs) {
            case let (.playbackFailed(a), .playbackFailed(b)),
                 let (.resourceLoadFailed(a), .resourceLoadFailed(b)):
                errors = (a, b)
            case let (.audioSessionFailed(a), .audioSessionFailed(b)):
                errors = (a, b)
            default:
                return false
            }
            switch errors {
            case (nil, nil): return true
            case let (a?, b?):
                return (a as NSError).domain == (b as NSError).domain && (a as NSError).code == (b as NSError).code
            default: return false
            }
        }
    }

    enum PlaybackStatus: Equatable {
        case idle
        case waiting // Preparing, seeking, or waiting for media data.
        case playing
        case paused
        case finished
        case failed(AVPlayerError)
    }

    enum MediaLoadState {
        case idle
        case loading
        case playable
    }
}

final class PoAVPlayerRenderView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// The session is global to the app. Multiple wrappers share ownership, so stopping
/// one player does not deactivate the session while another still needs it.
@MainActor
protocol PoAudioSessionManaging: AnyObject {
    func activate(owner: UUID) throws
    func deactivate(owner: UUID)
}

@MainActor
private final class PoPlaybackAudioSession: PoAudioSessionManaging {
    static let shared = PoPlaybackAudioSession()
    private var owners: Set<UUID> = []

    func activate(owner: UUID) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        owners.insert(owner)
    }

    func deactivate(owner: UUID) {
        guard owners.remove(owner) != nil, owners.isEmpty else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            PoDebugLog("Audio session deactivation failed:", error)
        }
    }
}

@MainActor
final class PoAVPlayer: NSObject {
    weak var delegate: PoAVPlayerDelegate?

    private(set) lazy var renderView: PoAVPlayerRenderView = {
        let view = PoAVPlayerRenderView()
        view.playerLayer.player = player
        return view
    }()

    /// Unknown and indefinite times are represented by nil, never NaN/infinity.
    var duration: Double? { finiteSeconds(player.currentItem?.duration) }
    var currentTime: Double? { finiteSeconds(player.currentItem?.currentTime()) }
    private(set) var playStatus = PlaybackStatus.idle
    private(set) var loadState = MediaLoadState.idle
    private(set) var isReadyToPlay = false
    /// The user's intent, including while preparing, buffering or interrupted.
    private(set) var wantsToPlay = false
    var isPlaying: Bool { playStatus == .playing }
    var isSeeking: Bool { pendingSeek != nil }
    /// Default for the next resource. Use resume/pause to control the current one.
    var autoPlayIfReady = true

    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }
    var isMuted: Bool {
        get { player.isMuted }
        set { player.isMuted = newValue }
    }
    /// Desired forward playback speed, retained across pause, seek and replacement.
    var rate: Float {
        get { preferredRate }
        set {
            guard newValue.isFinite, newValue > 0 else { return }
            preferredRate = newValue
            applyPlaybackIntent()
        }
    }
    var seekable: Bool { !(player.currentItem?.seekableTimeRanges.isEmpty ?? true) }

    private let player: AVPlayer
    private let audioSession: PoAudioSessionManaging
    private let sessionOwner = UUID()
    private var preferredRate: Float = 1
    private var itemGeneration = UUID()
    private var isInterrupted = false
    private var isAppInactive = false
    private var followsAppActivity = false
    private var appObservationGeneration = UUID()
    private var timeObserver: Any?
    private var playerObservation: NSKeyValueObservation?
    private var itemObservations: [NSKeyValueObservation] = []
    private var notificationObservers: [NSObjectProtocol] = []
    private var itemNotificationObservers: [NSObjectProtocol] = []
    private var appNotificationObservers: [NSObjectProtocol] = []

    private struct PendingSeek {
        let id: UUID
        let completion: ((Bool) -> Void)?
    }
    private var pendingSeek: PendingSeek?

    override convenience init() {
        self.init(player: AVPlayer(), audioSession: PoPlaybackAudioSession.shared)
    }

    // Injection keeps cancellation and transport behavior deterministically testable.
    init(player: AVPlayer, audioSession: PoAudioSessionManaging) {
        self.player = player
        self.audioSession = audioSession
        super.init()
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = true
        playerObservation = player.observe(\.timeControlStatus) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refreshState() }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isReadyToPlay, let item = self.player.currentItem else { return }
                self.delegate?.avplayer(self, periodicallyInvoke: item.currentTime())
            }
        }
        observeAudioSession()
    }

    isolated deinit {
        playerObservation?.invalidate()
        itemObservations.forEach { $0.invalidate() }
        (notificationObservers + itemNotificationObservers + appNotificationObservers).forEach {
            NotificationCenter.default.removeObserver($0)
        }

        if let observer = timeObserver { player.removeTimeObserver(observer) }
        player.pause()
        player.currentItem?.cancelPendingSeeks()
        player.currentItem?.asset.cancelLoading()
        player.replaceCurrentItem(with: nil)
        audioSession.deactivate(owner: sessionOwner)
        pendingSeek?.completion?(false)
    }

    func play(with url: URL) {
        replaceCurrentItem(with: AVPlayerItem(url: url))
    }

    func play(with item: AVPlayerItem) {
        replaceCurrentItem(with: item)
    }

    func resume() {
        guard player.currentItem != nil, !hasFailed else { return }
        if playStatus == .finished {
            replay()
            return
        }
        wantsToPlay = true
        applyPlaybackIntent()
    }

    func pause() {
        wantsToPlay = false
        applyPlaybackIntent()
    }

    func replay() {
        guard player.currentItem != nil, !hasFailed else { return }
        wantsToPlay = true
        if isReadyToPlay {
            seekToTime(0, isAccurateSeek: true)
        } else {
            // A newly preparing item already starts at zero.
            applyPlaybackIntent()
        }
    }

    func stop() {
        replaceCurrentItem(with: nil)
    }

    /// Seeking preserves the latest playback intent. Superseded requests complete
    /// once with false and can never change the current item or its playback state.
    func seekToTime(_ timeInterval: TimeInterval, isAccurateSeek: Bool = false, completionHandler: ((Bool) -> Void)? = nil) {
        guard timeInterval.isFinite, timeInterval >= 0, isReadyToPlay,
              let item = player.currentItem, !hasFailed else {
            completionHandler?(false)
            return
        }
        cancelSeek()
        let request = PendingSeek(id: UUID(), completion: completionHandler)
        let generation = itemGeneration
        pendingSeek = request
        if playStatus == .finished { setStatus(.paused) }
        guard itemGeneration == generation, pendingSeek?.id == request.id else { return }
        player.pause()
        refreshState()
        guard itemGeneration == generation, pendingSeek?.id == request.id else { return }
        let seconds = duration.map { min(timeInterval, $0) } ?? timeInterval
        let tolerance: CMTime = isAccurateSeek ? .zero : .positiveInfinity
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] success in
            MainActor.assumeIsolated {
                guard let self, self.itemGeneration == generation,
                      self.player.currentItem === item, self.pendingSeek?.id == request.id else { return }
                self.pendingSeek = nil
                if !success { self.wantsToPlay = false }
                self.applyPlaybackIntent()
                request.completion?(success)
            }
        }
    }

    func followAppActivityStatus(_ follow: Bool) {
        guard followsAppActivity != follow else { return }
        followsAppActivity = follow
        appObservationGeneration = UUID()
        let generation = appObservationGeneration
        if follow {
            isAppInactive = UIApplication.shared.applicationState != .active
            appNotificationObservers = [
                observe(UIApplication.willResignActiveNotification) { owner, _ in
                    guard owner.followsAppActivity, owner.appObservationGeneration == generation else { return }
                    owner.isAppInactive = true
                    owner.applyPlaybackIntent()
                },
                observe(UIApplication.didBecomeActiveNotification) { owner, _ in
                    guard owner.followsAppActivity, owner.appObservationGeneration == generation else { return }
                    owner.isAppInactive = false
                    owner.applyPlaybackIntent()
                }
            ]
        } else {
            appNotificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
            appNotificationObservers.removeAll()
            isAppInactive = false
        }
        applyPlaybackIntent()
    }

    private var hasFailed: Bool {
        if case .failed = playStatus { return true }
        return false
    }

    private func finiteSeconds(_ time: CMTime?) -> Double? {
        guard let time, time.isNumeric, time.seconds.isFinite, time.seconds >= 0 else { return nil }
        return time.seconds
    }

    private func cancelSeek() {
        let completion = pendingSeek?.completion
        pendingSeek = nil
        player.currentItem?.cancelPendingSeeks()
        // Deliver cancellation after the current operation has committed its state.
        if let completion { Task { @MainActor in completion(false) } }
    }

    private func replaceCurrentItem(with item: AVPlayerItem?) {
        itemGeneration = UUID()
        cancelSeek()
        itemObservations.forEach { $0.invalidate() }
        itemObservations.removeAll()
        itemNotificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        itemNotificationObservers.removeAll()
        player.pause()
        player.currentItem?.asset.cancelLoading()
        player.replaceCurrentItem(with: item)
        isReadyToPlay = false
        wantsToPlay = item != nil && autoPlayIfReady
        audioSession.deactivate(owner: sessionOwner)
        // Commit replacement before notifying callers, which may stop or replace again.
        let generation = itemGeneration
        setStatus(.idle)
        guard itemGeneration == generation else { return }
        setLoadState(item == nil ? .idle : .loading)
        guard itemGeneration == generation else { return }
        if let item { observeItem(item, generation: generation) }
    }

    private func applyPlaybackIntent() {
        guard player.currentItem != nil, !hasFailed, playStatus != .finished else {
            player.pause()
            audioSession.deactivate(owner: sessionOwner)
            return
        }
        if wantsToPlay && isReadyToPlay && !isSeeking && !isInterrupted && !isAppInactive {
            do {
                try audioSession.activate(owner: sessionOwner)
                if player.rate != preferredRate { player.rate = preferredRate }
            } catch {
                fail(.audioSessionFailed(error))
                return
            }
        } else {
            player.pause()
            audioSession.deactivate(owner: sessionOwner)
        }
        refreshState()
    }

    private func refreshState() {
        guard player.currentItem != nil, !hasFailed, playStatus != .finished else { return }
        let generation = itemGeneration
        let status: PlaybackStatus
        if !wantsToPlay || isInterrupted || isAppInactive {
            status = .paused
        } else if !isReadyToPlay || isSeeking || player.timeControlStatus != .playing {
            status = .waiting
        } else {
            status = .playing
        }
        setStatus(status)
        guard itemGeneration == generation, !hasFailed else { return }
        setLoadState(!isReadyToPlay || isSeeking || player.timeControlStatus == .waitingToPlayAtSpecifiedRate ? .loading : .playable)
    }

    private func setStatus(_ status: PlaybackStatus, forceNotify: Bool = false) {
        guard forceNotify || playStatus != status else { return }
        playStatus = status
        delegate?.avplayer(self, playerItemStatusChanged: status)
    }

    private func setLoadState(_ state: MediaLoadState) {
        guard loadState != state else { return }
        loadState = state
        delegate?.avplayer(self, loadStateChanged: state)
    }

    private func fail(_ error: AVPlayerError) {
        let generation = itemGeneration
        wantsToPlay = false
        isReadyToPlay = false
        cancelSeek()
        player.pause()
        audioSession.deactivate(owner: sessionOwner)
        setStatus(.failed(error), forceNotify: true)
        guard generation == itemGeneration else { return }
        setLoadState(.idle)
    }

    private func observe(_ name: Notification.Name, object: Any? = nil,
                         handler: @escaping @MainActor (PoAVPlayer, Notification) -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self, note)
            }
        }
    }

    private func observeAudioSession() {
        let session = AVAudioSession.sharedInstance()
        notificationObservers = [
            observe(AVAudioSession.interruptionNotification, object: session) { owner, note in
                guard let value = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: value) else { return }
                switch type {
                case .began:
                    owner.isInterrupted = true
                case .ended:
                    guard owner.isInterrupted else { return }
                    owner.isInterrupted = false
                    let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
                    if !AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                        owner.wantsToPlay = false
                    }
                @unknown default: return
                }
                owner.applyPlaybackIntent()
            },
            observe(AVAudioSession.routeChangeNotification, object: session) { owner, note in
                guard let value = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      AVAudioSession.RouteChangeReason(rawValue: value) == .oldDeviceUnavailable else { return }
                owner.pause()
            }
        ]
    }

    private func observeItem(_ item: AVPlayerItem, generation: UUID) {
        itemObservations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            MainActor.assumeIsolated {
                guard let self, self.itemGeneration == generation, self.player.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    guard !self.isReadyToPlay else { return }
                    self.isReadyToPlay = true
                    self.delegate?.avplayerPrepared(self)
                    guard self.itemGeneration == generation, self.isReadyToPlay else { return }
                    self.applyPlaybackIntent()
                case .failed:
                    self.fail(.resourceLoadFailed(item.error))
                default:
                    self.isReadyToPlay = false
                    self.applyPlaybackIntent()
                }
            }
        })
        itemObservations.append(item.observe(\.loadedTimeRanges, options: [.initial, .new]) { [weak self] item, _ in
            MainActor.assumeIsolated {
                guard let self, self.itemGeneration == generation, self.player.currentItem === item,
                      let range = item.loadedTimeRanges.first?.timeRangeValue else { return }
                self.delegate?.avplayer(self, loadedTimeRange: range)
            }
        })
        itemNotificationObservers = [
            observe(.AVPlayerItemDidPlayToEndTime, object: item) { owner, _ in
                guard owner.itemGeneration == generation, owner.player.currentItem === item, !owner.isSeeking, !owner.hasFailed else { return }
                owner.wantsToPlay = false
                owner.player.pause()
                owner.audioSession.deactivate(owner: owner.sessionOwner)
                owner.setStatus(.finished)
            },
            observe(.AVPlayerItemFailedToPlayToEndTime, object: item) { owner, note in
                guard owner.itemGeneration == generation, owner.player.currentItem === item else { return }
                owner.fail(.playbackFailed(note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error))
            }
        ]
    }
}

func PoDebugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    print(items, separator: separator, terminator: terminator)
    #endif
}
