import UIKit
import AVFoundation

protocol PoAVPlayerDelegate: AnyObject {
    /// 准备好播放
    func avplayerPrepared(_ player: PoAVPlayer)
    /// 音视频资源加载的状态
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: PoAVPlayer.PlaybackStatus)
    /// 缓冲到了哪儿
    func avplayer(_ player: PoAVPlayer, loadedTimeRange range: CMTimeRange)
    /// 缓冲数据是否够用
    func avplayer(_ player: PoAVPlayer, loadStateChanged state: PoAVPlayer.MediaLoadState)
    /// 播放时周期性回调
    func avplayer(_ player: PoAVPlayer, periodicallyInvoke time: CMTime)
}

extension PoAVPlayerDelegate {
    /// 准备好播放
    func avplayerPrepared(_ player: PoAVPlayer) {}
    /// 音视频资源加载的状态
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: PoAVPlayer.PlaybackStatus) {}
    /// 缓冲到了哪儿
    func avplayer(_ player: PoAVPlayer, loadedTimeRange range: CMTimeRange) {}
    /// 缓冲数据是否够用
    func avplayer(_ player: PoAVPlayer, loadStateChanged state: PoAVPlayer.MediaLoadState) {}
    /// 播放时周期性回调
    func avplayer(_ player: PoAVPlayer, periodicallyInvoke time: CMTime) {}
}

extension PoAVPlayer {
    
    /// 播放器错误类型
    public enum AVPlayerError: Error {
        case playbackFailed(Error?)
        case resourceLoadFailed(Error?)
    }
    
    public enum PlaybackStatus: Equatable {
        case idle // 初始状态
        case playing // 资源异步加载中
        case paused  // 暂停
        case finished // 播放结束
        case failed(AVPlayerError) // 错误发生
        
        public static func == (lhs: PlaybackStatus, rhs: PlaybackStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.paused, .paused), (.playing, .playing), (.finished, .finished): return true
            case (.failed, .failed): return false // 错误通常不相等以便触发更新
            default: return false
            }
        }
    }

    public enum MediaLoadState: Int {
        case idle
        case loading
        case playable
    }

}

class PoAVPlayerRenderView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

class PoAVPlayer: NSObject {
    
    // MARK: - Properties
    
    public weak var delegate: PoAVPlayerDelegate?
    
    public let renderView: PoAVPlayerRenderView = PoAVPlayerRenderView()
    
    /// seconds
    public var duration: Double? {
        currentPlayerItem?.duration.seconds
    }
    
    /// seconds
    public var currentTime: Double? {
        currentPlayerItem?.currentTime().seconds
    }
    
    public private(set) var loadState = MediaLoadState.idle {
        didSet {
            if loadState == oldValue { return }
            PoDebugLog("PoAVPlayer loadStateChanged: \(loadState)")
            delegate?.avplayer(self, loadStateChanged: loadState)
        }
    }

    private var _playStatus = PlaybackStatus.idle
    public var playStatus: PlaybackStatus {
        get { _playStatus }
        set {
            if _playStatus == newValue { return }
            _playStatus = newValue
            
            if case .failed = playStatus {
                isReadyToPlay = false
            }
            if _playStatus != .finished {
                playOrPause()
            }
            PoDebugLog("PoAVPlayer playerItemStatusChanged: \(playStatus)")
            delegate?.avplayer(self, playerItemStatusChanged: playStatus)
        }
    }

    public private(set) var isReadyToPlay = false
    
    public var autoPlayIfReady: Bool = true {
        didSet {
            shouldPlay = autoPlayIfReady
        }
    }
    private var shouldPlay: Bool = true
    
    public var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }
    
    public var isMuted: Bool {
        get { player.isMuted }
        set { player.isMuted = newValue }
    }
    
    public var rate: Float {
        get { player.rate }
        set { player.rate = newValue }
    }
    
    public var seekable: Bool {
        !(player.currentItem?.seekableTimeRanges.isEmpty ?? true)
    }
    
    /// 是否播放中
    public var isPlaying: Bool {
        player.rate > 0 ? true : playStatus == .playing
    }
    
    private lazy var player: AVPlayer = AVPlayer(playerItem: nil)
    private var currentPlayerItem: AVPlayerItem?
    private var isPlayingBeforeResignActive: Bool = false
    
    private var timeObserver: Any?
    private var templateObservations: [NSKeyValueObservation] = []
    
    
    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if currentPlayerItem != nil {
            stop()
        }
        notificationObservers.forEach({ NotificationCenter.default.removeObserver($0) })
        NotificationCenter.default.removeObserver(self)
    }
    
    override init() {
        super.init()
        setup()
    }
    
    private func setup() {
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = false
        (renderView.layer as! AVPlayerLayer).player = player
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: DispatchQueue.main) { [weak self] (time) in
            guard let self else { return }
            
            self.delegate?.avplayer(self, periodicallyInvoke: time)
        }
        
        setupAudioSession()
    }
    
    private var notificationObservers: [any NSObjectProtocol] = []
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        
        let interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] notification in
            guard let self,
                    let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            switch type {
            case .began:
                isPlayingBeforeResignActive = isPlaying
                if isPlayingBeforeResignActive {
                    pause()
                }
            case .ended:
                let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                    if isPlayingBeforeResignActive {
                        resume()
                    }
                }
            @unknown default:
                break
            }
        }
        notificationObservers.append(interruptionObserver)
        
        let routeChangeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] notification in
//            guard let self, let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
//                    let routeChangeReason = AVAudioSession.RouteChangeReason(rawValue: value) else { return }
//            switch routeChangeReason {
//            case .newDeviceAvailable:
////                if session.currentRoute.outputs.contains(where: { $0.portType == .headphones || $0.portType == .bluetoothA2DP }) {
////                    resume()
////                }
//                break
//            case .oldDeviceUnavailable:
//                pause()
//            default:
//                break
//            }
            guard let self,
                    let routeDescription = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else { return }
            // 之前有耳机，现在没有耳机
            if routeDescription.outputs.contains(where: { $0.portType == .headphones || $0.portType == .bluetoothA2DP }),
                session.currentRoute.outputs.contains(where: { $0.portType == .headphones || $0.portType == .bluetoothA2DP }) == false {
                pause()
            }
        }
        notificationObservers.append(routeChangeObserver)
    }
    
    
    
    // MARK: - Public Method
    
    /// 播放url对应的音/视频文件
    func play(with url: URL) {
        play(with: AVPlayerItem(url: url))
    }
    
    
    /// 播放item中的音/视频文件
    /// - Parameter item: item
    private func play(with item: AVPlayerItem) {
        PoDebugLog("PoAVPlayer play: \((item.asset as? AVURLAsset)?.url, default: "")")
        isReadyToPlay = false
        shouldPlay = autoPlayIfReady
        playStatus = .idle
        loadState = .idle
        replaceCurrentItem(playerItem: item)
    }
    
    /// 播放(如果finished状态，则不做任何事)
    func resume() {
        PoDebugLog("PoAVPlayer resume")
        if !canConvertToState(from: playStatus, to: .playing) {
            return
        }
        shouldPlay = true
        if !isReadyToPlay { return }
        playStatus = .playing
    }
    
    /// 暂停
    func pause() {
        PoDebugLog("PoAVPlayer pause")
        if !canConvertToState(from: playStatus, to: .paused) {
            return
        }
        shouldPlay = false
        if !isReadyToPlay { return }
        playStatus = .paused
    }
    
    /// 重播()
    func replay() {
        PoDebugLog("PoAVPlayer replay")
        if !canConvertToState(from: playStatus, to: .playing) {
            return
        }
        shouldPlay = true
        if !isReadyToPlay { return }
        playStatus = .playing
        seekToTime(0)
    }
    
    /// 释放当前播放资源
    func stop() {
        PoDebugLog("PoAVPlayer stop")
        isReadyToPlay = false
        shouldPlay = false
        playStatus = .idle
        loadState = .idle
        replaceCurrentItem(playerItem: nil)
    }
    
    /// 跳转到指定时间点
    /// - Parameters:
    ///   - timeInterval: 新的时间点(单位秒)
    ///   - completionHandler: 跳转完成后执行
    func seekToTime(_ timeInterval: TimeInterval, isAccurateSeek: Bool = false, completionHandler: ((Bool) -> Void)? = nil) {
        PoDebugLog("PoAVPlayer seek: \(timeInterval) isAccurateSeek: \(isAccurateSeek)")
        guard let playItem = currentPlayerItem, timeInterval >= 0, isReadyToPlay else {
            completionHandler?(false)
            PoDebugLog("PoAVPlayer seek: \(timeInterval) failure")
            return
        }
        player.pause()
        let seconds = playItem.duration.seconds > timeInterval ? timeInterval : playItem.duration.seconds
        let tolerance: CMTime = isAccurateSeek ? .zero : .positiveInfinity
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] success in
            guard let self else { return }
            player.play()
            _playStatus = .playing
            delegate?.avplayer(self, playerItemStatusChanged: .playing)
            completionHandler?(success)
            PoDebugLog("PoAVPlayer seek: \(timeInterval) \(success ? "success" : "failure")")
        }
    }
    
    /// 是否在回前台时播放，退后台时暂停
    func followAppActityStatus(_ follow: Bool) {
        if follow {
            addAppNotification()
        } else {
            removeAppNotification()
        }
    }
    
    // MARK: - Notification
    
    private var hasRegisterAppNotification = false
    private func addAppNotification() {
        if hasRegisterAppNotification { return }
        hasRegisterAppNotification = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    private func removeAppNotification() {
        if !hasRegisterAppNotification { return }
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private func replaceCurrentItem(playerItem: AVPlayerItem?) {
        player.pause()
        player.currentItem?.cancelPendingSeeks()
        player.currentItem?.asset.cancelLoading()
        _removeObserver(for: currentPlayerItem)
        self.currentPlayerItem = playerItem
        
        if let playerItem {
            addObserver(for: playerItem)
        }
        player.replaceCurrentItem(with: playerItem)
    }
    
    private func playOrPause() {
        if playStatus == .playing {
            if isReadyToPlay {
                player.play()
            }
        } else {
            player.pause()
        }
    }
    
    private func canConvertToState(from: PlaybackStatus, to: PlaybackStatus) -> Bool {
        if from == to { return false }
        switch (from, to) {
        case (.failed, .idle):
            return true
        case (.failed, _):
            return false
        case (.finished, .failed), (.finished, .paused):
            return false
        default:
            return true
        }
    }
    
    // MARK: - Observer
    
    private func addObserver(for playerItem: AVPlayerItem) {
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidFailedPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)

        let statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay:
                PoDebugLog("PoAVPlayer readyToPlay")
                self.isReadyToPlay = true
                self.delegate?.avplayerPrepared(self)
                if shouldPlay {
                    playStatus = .playing
                } else {
                    playStatus = .paused
                }
            case .failed:
                PoDebugLog("PoAVPlayer status failed")
                playStatus = .failed(.resourceLoadFailed(item.error))
            default:
                break
            }
        }
        templateObservations.append(statusObservation)
        
        let loadedTimeRangesObservation = playerItem.observe(\.loadedTimeRanges, options: .new) { [weak self] item, value in
            guard let self else { return }
            if let range = value.newValue?.first?.timeRangeValue {
                delegate?.avplayer(self, loadedTimeRange: range)
            }
        }
        templateObservations.append(loadedTimeRangesObservation)

        let changeHandler: (AVPlayerItem, NSKeyValueObservedChange<Bool>) -> Void = { [weak self] item, _ in
            guard let self else { return }
            if item.isPlaybackBufferEmpty {
                self.loadState = .loading
            } else if item.isPlaybackLikelyToKeepUp || item.isPlaybackBufferFull {
                self.loadState = .playable
            }
        }
        let bufferEmptyObservation = playerItem.observe(\.isPlaybackBufferEmpty, changeHandler: changeHandler)
        templateObservations.append(bufferEmptyObservation)
        let likelyToKeepUpObservation = playerItem.observe(\.isPlaybackLikelyToKeepUp, changeHandler: changeHandler)
        templateObservations.append(likelyToKeepUpObservation)
        let bufferFullObservation = playerItem.observe(\.isPlaybackBufferFull, changeHandler: changeHandler)
        templateObservations.append(bufferFullObservation)
    }
    
    private func _removeObserver(for playerItem: AVPlayerItem?) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        templateObservations.forEach { $0.invalidate() }
        templateObservations.removeAll()
    }
    
    @objc
    private func appResignActive() {
        isPlayingBeforeResignActive = isPlaying
        if isPlayingBeforeResignActive {
            pause()
        }
    }
    
    @objc
    private func appBecomeActive() {
        if isPlayingBeforeResignActive {
            resume()
        }
    }
    
    @objc
    private func playerItemDidPlayToEndTime() {
        PoDebugLog("PoAVPlayer playerItemDidPlayToEndTime")
        playStatus = .finished
    }
    
    @objc
    private func playerItemDidFailedPlayToEndTime(_ notification: Notification) {
        var playError: Error?
        if let userInfo = notification.userInfo {
            if let error = userInfo["error"] as? Error {
                playError = error
            } else if let error = userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError {
                playError = error
            } else if let errorCode = (userInfo["error"] as? NSNumber)?.intValue {
                playError = NSError(domain: "PoAvPlayer", code: errorCode, userInfo: nil)
            }
        }
        PoDebugLog("PoAVPlayer playerItemDidFailedPlayToEndTime: \(playError?.localizedDescription ?? "")")
        playStatus = .failed(.playbackFailed(playError))
    }
}

func PoDebugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    print(items, separator: separator, terminator: terminator)
    #endif
}
