import XCTest
import AVFoundation
import UIKit
@testable import PoReader

@MainActor
final class PoAVPlayerTests: XCTestCase {
    private func drain() async { try? await Task.sleep(nanoseconds: 20_000_000) }

    private func ready(autoPlay: Bool = true) async -> (PoAVPlayer, ControlledPlayer, TestAudioSession) {
        let transport = ControlledPlayer()
        let session = TestAudioSession()
        let player = PoAVPlayer(player: transport, audioSession: session)
        player.autoPlayIfReady = autoPlay
        player.play(with: ReadyItem())
        await drain()
        XCTAssertTrue(player.isReadyToPlay)
        return (player, transport, session)
    }

    func testSeekWhilePausedStaysPaused() async {
        let (player, transport, _) = await ready(autoPlay: false)
        var results: [Bool] = []
        player.seekToTime(5) { results.append($0) }
        transport.completeSeek(0)
        await drain()
        XCTAssertEqual(results, [true])
        XCTAssertEqual(player.playStatus, .paused)
        XCTAssertEqual(transport.rate, 0)
        XCTAssertFalse(player.wantsToPlay)
    }

    func testRateSurvivesPauseSeekAndReplacement() async {
        let (player, transport, _) = await ready()
        player.rate = 1.5
        player.pause()
        player.resume()
        XCTAssertEqual(transport.rate, 1.5)
        player.seekToTime(5)
        transport.completeSeek(0)
        await drain()
        XCTAssertEqual(transport.rate, 1.5)
        player.play(with: ReadyItem())
        await drain()
        XCTAssertEqual(transport.rate, 1.5)
        XCTAssertEqual(player.rate, 1.5)
        player.rate = .nan
        player.rate = 0
        XCTAssertEqual(player.rate, 1.5)
    }

    func testPauseDuringSeekOverridesEarlierPlayIntent() async {
        let (player, transport, _) = await ready()
        player.seekToTime(5)
        player.pause()
        transport.completeSeek(0)
        await drain()
        XCTAssertEqual(player.playStatus, .paused)
        XCTAssertEqual(transport.rate, 0)
    }

    func testSupersededSeekCompletesOnceAndCannotResumePlayback() async {
        let (player, transport, _) = await ready()
        var first: [Bool] = []
        var second: [Bool] = []
        player.seekToTime(5) { first.append($0) }
        player.seekToTime(10) { second.append($0) }
        await drain()
        XCTAssertEqual(first, [false])
        transport.completeSeek(0, success: false)
        await drain()
        XCTAssertTrue(player.isSeeking)
        XCTAssertEqual(transport.rate, 0)
        XCTAssertEqual(first, [false])
        transport.completeSeek(1)
        await drain()
        XCTAssertEqual(second, [true])
        XCTAssertEqual(player.playStatus, .playing)
    }

    func testStopInvalidatesSeekAndEndNotification() async {
        let (player, transport, _) = await ready()
        let oldItem = transport.currentItem!
        var results: [Bool] = []
        player.seekToTime(3) { results.append($0) }
        // Queue an item event before stop; its main-actor handler runs afterwards.
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: oldItem)
        player.stop()
        transport.completeSeek(0)
        await drain()
        XCTAssertEqual(results, [false])
        XCTAssertEqual(player.playStatus, .idle)
        XCTAssertEqual(player.loadState, .idle)
        XCTAssertFalse(player.wantsToPlay)
        XCTAssertNil(transport.currentItem)
        XCTAssertEqual(transport.rate, 0)
    }

    func testReplacementRejectsOldSeekCompletion() async {
        let (player, transport, _) = await ready()
        var results: [Bool] = []
        player.seekToTime(3) { results.append($0) }
        player.autoPlayIfReady = false
        let newItem = ReadyItem()
        player.play(with: newItem)
        transport.completeSeek(0)
        await drain()
        XCTAssertEqual(results, [false])
        XCTAssertTrue(transport.currentItem === newItem)
        XCTAssertEqual(player.playStatus, .paused)
        XCTAssertEqual(transport.rate, 0)
    }

    func testReplayWhilePlayingAndResumeAfterEndSeekToZero() async {
        let (player, transport, _) = await ready()
        player.replay()
        XCTAssertEqual(transport.seeks.count, 1)
        XCTAssertEqual(transport.seeks[0].time, .zero)
        transport.completeSeek(0)
        await drain()
        XCTAssertEqual(player.playStatus, .playing)
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: transport.currentItem)
        await drain()
        XCTAssertEqual(player.playStatus, .finished)
        player.resume()
        XCTAssertEqual(transport.seeks.count, 2)
        XCTAssertEqual(transport.seeks[1].time, .zero)
        transport.completeSeek(1)
        await drain()
        XCTAssertEqual(player.playStatus, .playing)
    }

    func testAppActivityCanBeDisabledAndEnabledAgain() async {
        let (player, transport, _) = await ready()
        player.followAppActivityStatus(true)
        player.followAppActivityStatus(false)
        player.followAppActivityStatus(true)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await drain()
        XCTAssertEqual(transport.rate, 1)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        await drain()
        XCTAssertEqual(transport.rate, 0)
        XCTAssertTrue(player.wantsToPlay)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await drain()
        XCTAssertEqual(transport.rate, 1)
    }

    private func interruption(_ type: AVAudioSession.InterruptionType, resume: Bool = true) {
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification,
                                        object: AVAudioSession.sharedInstance(), userInfo: [
                                            AVAudioSessionInterruptionTypeKey: type.rawValue,
                                            AVAudioSessionInterruptionOptionKey: resume ? AVAudioSession.InterruptionOptions.shouldResume.rawValue : 0
                                        ])
    }

    func testOverlappingInterruptionAndAppInactivityRestoreOnlyWhenBothEnd() async {
        let (player, transport, _) = await ready()
        player.followAppActivityStatus(true)
        interruption(.began)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        await drain()
        XCTAssertEqual(transport.rate, 0)
        XCTAssertTrue(player.wantsToPlay)
        interruption(.ended)
        await drain()
        XCTAssertEqual(transport.rate, 0)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await drain()
        XCTAssertEqual(transport.rate, 1)
    }

    func testUserPauseAndStopDuringInterruptionPreventResume() async {
        let (player, transport, _) = await ready()
        interruption(.began)
        await drain()
        player.pause()
        interruption(.ended)
        await drain()
        XCTAssertEqual(transport.rate, 0)
        XCTAssertFalse(player.wantsToPlay)
        player.resume()
        interruption(.began)
        await drain()
        player.stop()
        interruption(.ended)
        await drain()
        XCTAssertEqual(player.playStatus, .idle)
        XCTAssertEqual(transport.rate, 0)
    }

    func testInterruptionWithoutPermissionDoesNotResume() async {
        let (player, transport, _) = await ready()
        interruption(.began)
        await drain()
        interruption(.ended, resume: false)
        await drain()
        XCTAssertEqual(transport.rate, 0)
        XCTAssertFalse(player.wantsToPlay)
    }

    func testFailedSeekDoesNotStartPlayback() async {
        let (player, transport, _) = await ready()
        var result: Bool?
        player.seekToTime(5) { result = $0 }
        transport.completeSeek(0, success: false)
        await drain()
        XCTAssertEqual(result, false)
        XCTAssertFalse(player.isSeeking)
        XCTAssertEqual(player.playStatus, .paused)
    }

    func testInvalidTimesAreRejectedAndUnknownDurationIsNotConvertedToNaN() async {
        let (player, transport, _) = await ready(autoPlay: false)
        var results: [Bool] = []
        for value in [Double.nan, .infinity, -.infinity, -1] {
            player.seekToTime(value) { results.append($0) }
        }
        XCTAssertEqual(results, [false, false, false, false])
        XCTAssertTrue(transport.seeks.isEmpty)
        player.seekToTime(100)
        XCTAssertEqual(transport.seeks.last?.time.seconds, 20)
        let indefinite = ReadyItem()
        indefinite.testDuration = .indefinite
        player.play(with: indefinite)
        await drain()
        XCTAssertNil(player.duration)
        player.seekToTime(5)
        XCTAssertEqual(transport.seeks.last?.time.seconds, 5)
    }

    func testSessionFailureIsReportedAndErrorEqualityIsReflexive() async {
        let transport = ControlledPlayer()
        let session = TestAudioSession()
        session.error = NSError(domain: "TestSession", code: 7)
        let player = PoAVPlayer(player: transport, audioSession: session)
        player.play(with: ReadyItem())
        await drain()
        guard case .failed(.audioSessionFailed) = player.playStatus else {
            return XCTFail("Expected session activation failure")
        }
        XCTAssertEqual(player.playStatus, player.playStatus)
        XCTAssertFalse(player.isReadyToPlay)
        XCTAssertFalse(player.wantsToPlay)
        XCTAssertEqual(transport.rate, 0)
    }

    func testPreparedDelegateCanStopWithoutStalePlayback() async {
        let transport = ControlledPlayer()
        let player = PoAVPlayer(player: transport, audioSession: TestAudioSession())
        let delegate = PlayerDelegate()
        delegate.prepared = { $0.stop() }
        player.delegate = delegate
        player.play(with: ReadyItem())
        await drain()
        XCTAssertEqual(player.playStatus, .idle)
        XCTAssertNil(transport.currentItem)
        XCTAssertEqual(transport.rate, 0)
    }

    func testDeinitCleansUpWithoutStatusDelegateCallback() async {
        let transport = ControlledPlayer()
        let session = TestAudioSession()
        let delegate = PlayerDelegate()
        var player: PoAVPlayer? = PoAVPlayer(player: transport, audioSession: session)
        weak let weakPlayer = player
        player?.delegate = delegate
        player?.play(with: ReadyItem())
        await drain()
        var results: [Bool] = []
        player?.seekToTime(5) { results.append($0) }
        let oldCount = delegate.statuses.count
        player = nil
        await drain()
        XCTAssertNil(weakPlayer)
        XCTAssertNil(transport.currentItem)
        XCTAssertEqual(delegate.statuses.count, oldCount)
        XCTAssertEqual(results, [false])
        XCTAssertTrue(session.owners.isEmpty)
        transport.completeSeek(0)
        await drain()
        XCTAssertEqual(results, [false])
    }

    func testSeekingDelegateCanStopBeforeNativeSeekStarts() async {
        let (player, transport, _) = await ready()
        let delegate = PlayerDelegate()
        delegate.statusChanged = { player, status in
            if status == .waiting { player.stop() }
        }
        player.delegate = delegate
        var results: [Bool] = []
        player.seekToTime(5) { results.append($0) }
        await drain()
        XCTAssertEqual(results, [false])
        XCTAssertTrue(transport.seeks.isEmpty)
        XCTAssertEqual(player.playStatus, .idle)
    }

    func testRetiredAppObserverCannotAffectNewRegistration() async {
        let (player, transport, _) = await ready()
        player.followAppActivityStatus(true)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await drain()
        // The old observer's Task is queued, but its registration is now retired.
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        player.followAppActivityStatus(false)
        player.followAppActivityStatus(true)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await drain()
        XCTAssertTrue(player.wantsToPlay)
        XCTAssertEqual(transport.rate, 1)
    }

    func testRouteLossClearsPlaybackIntent() async {
        let (player, transport, _) = await ready()
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification,
                                        object: AVAudioSession.sharedInstance(), userInfo: [
                                            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
                                        ])
        await drain()
        XCTAssertFalse(player.wantsToPlay)
        XCTAssertEqual(transport.rate, 0)
    }

    func testNativePlayerLoadsLocalAudioAndSeeksWhilePaused() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        var data = Data()
        func ascii(_ s: String) { data.append(contentsOf: s.utf8) }
        func integer<T: FixedWidthInteger>(_ n: T) {
            var value = n.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        let byteCount: UInt32 = 160000 // 10 seconds of mono, 8 kHz, 16-bit silence.
        ascii("RIFF"); integer(byteCount + 36); ascii("WAVEfmt ")
        integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(1))
        integer(UInt32(8000)); integer(UInt32(16000)); integer(UInt16(2)); integer(UInt16(16))
        ascii("data"); integer(byteCount); data.append(Data(count: Int(byteCount)))
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let player = PoAVPlayer(player: AVPlayer(), audioSession: TestAudioSession())
        defer { player.stop() }
        player.autoPlayIfReady = false
        player.play(with: url)
        for _ in 0..<250 where !player.isReadyToPlay { await drain() }
        guard player.isReadyToPlay else {
            let wrapperStatus = player.playStatus
            // Distinguish wrapper regressions from unavailable simulator audio I/O.
            player.stop()
            let control = AVPlayer(url: url)
            for _ in 0..<250 where control.currentItem?.status == .unknown { await drain() }
            let controlStatus = control.currentItem?.status.rawValue ?? -1
            let controlError = String(describing: control.currentItem?.error)
            control.pause()
            control.replaceCurrentItem(with: nil)
            print("NATIVE_AUDIO_CONTROL status=\(controlStatus) error=\(controlError)")
            return XCTFail("Native audio did not become ready: \(wrapperStatus); AVPlayer control status=\(controlStatus), error=\(controlError)")
        }
        XCTAssertEqual(try XCTUnwrap(player.duration), 10, accuracy: 0.01)
        let finished = expectation(description: "Native seek")
        player.seekToTime(2, isAccurateSeek: true) { success in
            XCTAssertTrue(success)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertEqual(player.playStatus, .paused)
        XCTAssertEqual(try XCTUnwrap(player.currentTime), 2, accuracy: 0.05)
    }
}

private final class ReadyItem: AVPlayerItem {
    var testDuration = CMTime(seconds: 20, preferredTimescale: 600)
    override var status: AVPlayerItem.Status { .readyToPlay }
    override var duration: CMTime { testDuration }
    init() { super.init(asset: AVMutableComposition(), automaticallyLoadedAssetKeys: nil) }
}

private final class ControlledPlayer: AVPlayer {
    struct Seek {
        let time: CMTime
        let completion: (Bool) -> Void
    }
    var seeks: [Seek] = []
    private var item: AVPlayerItem?
    private var testRate: Float = 0
    override var currentItem: AVPlayerItem? { item }
    override var rate: Float {
        get { testRate }
        set { testRate = newValue }
    }
    override var timeControlStatus: AVPlayer.TimeControlStatus { testRate > 0 ? .playing : .paused }
    override func pause() { testRate = 0 }
    override func replaceCurrentItem(with item: AVPlayerItem?) { self.item = item }
    override func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime,
                       completionHandler: @escaping (Bool) -> Void) {
        seeks.append(Seek(time: time, completion: completionHandler))
    }
    func completeSeek(_ index: Int, success: Bool = true) { seeks[index].completion(success) }
}

@MainActor
private final class TestAudioSession: PoAudioSessionManaging {
    var owners: Set<UUID> = []
    var error: Error?
    func activate(owner: UUID) throws {
        if let error { throw error }
        owners.insert(owner)
    }
    func deactivate(owner: UUID) { owners.remove(owner) }
}

@MainActor
private final class PlayerDelegate: PoAVPlayerDelegate {
    var statuses: [PoAVPlayer.PlaybackStatus] = []
    var prepared: ((PoAVPlayer) -> Void)?
    var statusChanged: ((PoAVPlayer, PoAVPlayer.PlaybackStatus) -> Void)?
    func avplayerPrepared(_ player: PoAVPlayer) { prepared?(player) }
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: PoAVPlayer.PlaybackStatus) {
        statuses.append(status)
        statusChanged?(player, status)
    }
}
