import UIKit
import AVFoundation
import MediaPlayer

class AudioPlayerView: UIView {
    private let player: PoAVPlayer = PoAVPlayer()
    
    var onStop: ((_ model: AudioModel?, _ progress: Float) -> Void)?
    
    private let titleLabel: UILabel = UILabel()
    private let activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .medium)
    private let timeLabel: UILabel = UILabel()
    private let playButton: UIButton = UIButton(type: .custom)
    private let stopButton: UIButton = UIButton(type: .custom)
    private let progress: MediaProgressView = MediaProgressView()
    private var seekProgress: TimeInterval?
    private var terminationObserver: NSObjectProtocol?
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var remoteRegistration = UUID()
    
    var progressValue: Float { progress.sliderValue }
    
    isolated deinit {
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        remoteTargets.forEach { $0.0.removeTarget($0.1) }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private(set) var currentModel: AudioModel?
    func play(with model: AudioModel, progress: Double) {
        if currentModel != nil {
            stop()
        }
        currentModel = model
        seekProgress = progress
        titleLabel.text = model.name
        player.delegate = self
        player.play(with: model.localPath)
    }
    
    func stop() {
        player.stop()
        removeRemote()
        onStop?(currentModel, progressValue)
        
        currentModel = nil
        titleLabel.text = "-:-"
        progress.sliderValue = 0
        timeLabel.text = "00:00/00:00"
    }
    
    private func setupUI() {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stopButton.tintColor = .white
        stopButton.setImage(UIImage(systemName: "xmark.circle"), for: .normal)
        stopButton.addTarget(self, action: #selector(stopButtonHandle(_:)), for: .touchUpInside)
        addSubview(stopButton)
        stopButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(5)
            make.trailing.equalToSuperview().offset(-5)
            make.width.height.equalTo(25)
        }
        
        // 名称
        titleLabel.textColor = UIColor.white
        titleLabel.text = "-:-"
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(5)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-40)
        }
        
        // 播放/暂停按钮
        playButton.tintColor = .white
        playButton.imageView?.contentMode = .scaleAspectFill
        playButton.setImage(UIImage(systemName: "play.circle"), for: .normal)
        playButton.setImage(UIImage(systemName: "pause.circle"), for: .selected)
        playButton.addTarget(self, action: #selector(playButtonHandle(_:)), for: .touchUpInside)
        addSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.leading.equalTo(titleLabel)
            make.width.height.equalTo(30)
        }
        
        // 当前播放时间
        timeLabel.text = "00:00/00:00"
        timeLabel.textColor = UIColor.white
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textAlignment = .right
        addSubview(timeLabel)
        timeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(playButton)
            make.trailing.equalTo(titleLabel)
            make.width.equalTo(67)
        }
        
        // 播放/缓冲进度
        progress.isContinuous = false
        progress.addTarget(self, action: #selector(AudioPlayerView.progressChangeHandle(_:)), for: .valueChanged)
        addSubview(progress)
        progress.snp.makeConstraints { make in
            make.leading.equalTo(playButton.snp.trailing).offset(5)
            make.trailing.equalTo(timeLabel.snp.leading).offset(-5)
            make.centerY.equalTo(playButton)
            make.height.equalTo(30)
        }
        
        terminationObserver = NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.onStop?(self.currentModel, self.progressValue)
            }
        }
    }
    
    // MARK: - selector
    @objc
    private func stopButtonHandle(_ sender: UIButton) {
        stop()
    }
    
    @objc
    private func playButtonHandle(_ sender: UIButton) {
        if player.wantsToPlay {
            player.pause()
        } else {
            if player.playStatus == .finished {
                player.replay()
            } else {
                player.resume()
            }
        }
    }
    
    @objc
    private func progressChangeHandle(_ sender: MediaProgressView) {
        guard let duration = player.duration else { return }
        
        let target = Double(sender.sliderValue) * duration
        player.seekToTime(target)
    }
    
    // MARK: - helper
    
    private func updateTime(current: Double, duration: Double?) {
        guard let duration else {
            timeLabel.text = "00:00/00:00"
            return
        }
        timeLabel.text = "\(formartDuration(current))/\(formartDuration(duration))"
    }
    
    private func formartDuration(_ duration: Double) -> String {
        if duration.isNaN || duration.isInfinite { return "00:00" }
        
        let duration = Int(duration)
        let second = duration % 60
        let minute = duration / 60
        return String(format: "%02d:%02d", minute, second)
    }
}

extension AudioPlayerView {
    private func updateNowPlayingInfo(title: String?) {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        registerRemoteControllEvent()
        
        var playingInfo = [String: Any]()
        playingInfo[MPMediaItemPropertyTitle] = title
        MPNowPlayingInfoCenter.default().nowPlayingInfo = playingInfo
    }
    
    private func updateNowPlayingInfo(current: TimeInterval, duration: TimeInterval) {
        guard current.isFinite, duration.isFinite else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = current
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? player.rate : 0
    }
    
    func removeRemote() {
        guard !remoteTargets.isEmpty else { return }
        remoteRegistration = UUID()
        remoteTargets.forEach { $0.0.removeTarget($0.1) }
        remoteTargets.removeAll()
        UIApplication.shared.endReceivingRemoteControlEvents()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    private func registerRemoteControllEvent() {
        guard remoteTargets.isEmpty else { return }
        let registration = remoteRegistration
        let commands = MPRemoteCommandCenter.shared()
        func register(_ command: MPRemoteCommand, action: @escaping @MainActor (AudioPlayerView) -> Void) {
            let token = command.addTarget { [weak self] _ in
                guard let self else { return .commandFailed }
                Task { @MainActor [weak self] in
                    guard let self, self.currentModel != nil, self.remoteRegistration == registration else { return }
                    action(self)
                }
                return .success
            }
            remoteTargets.append((command, token))
        }
        register(commands.playCommand) { $0.player.resume() }
        register(commands.pauseCommand) { $0.player.pause() }
        register(commands.togglePlayPauseCommand) {
            if $0.player.wantsToPlay { $0.player.pause() } else { $0.player.resume() }
        }
        register(commands.stopCommand) { $0.stop() }
    }
}


// MARK: - PoAVPlayerDelegate
extension AudioPlayerView: PoAVPlayerDelegate {
    
    func avplayerPrepared(_ player: PoAVPlayer) {
        updateTime(current: 0, duration: player.duration)
        updateNowPlayingInfo(title: titleLabel.text)
        if let seekProgress, let duration = player.duration, duration.isNormal {
            player.seekToTime(seekProgress * duration)
        }
        seekProgress = nil
    }
    
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: PoAVPlayer.PlaybackStatus) {
        switch status {
        case .idle:
            playButton.isSelected = false
            removeRemote()
        case .paused, .finished:
            playButton.isSelected = false
        case .waiting:
            playButton.isSelected = player.wantsToPlay
        case .playing:
            playButton.isSelected = true
        case .failed(let error):
            playButton.isSelected = false
            removeRemote()
            PoDebugLog(error)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? player.rate : 0
    }
    
    /// 缓冲到了哪儿
    func avplayer(_ player: PoAVPlayer, loadedTimeRange range: CMTimeRange) {
        let loaded = range.end.seconds
        guard loaded.isFinite, let duration = player.duration, duration > 0 else { return }
        progress.progressValue = Float(min(max(loaded / duration, 0), 1))
    }
    
    /// 缓冲数据是否够用
    func avplayer(_ player: PoAVPlayer, loadStateChanged state: PoAVPlayer.MediaLoadState) {
        switch state {
        case .loading:
            activityIndicator.startAnimating()
        default:
            activityIndicator.stopAnimating()
        }
    }
    
    /// 播放时周期性回调
    func avplayer(_ player: PoAVPlayer, periodicallyInvoke time: CMTime) {
        guard let duration = player.duration, duration.isNormal, duration > 0 else { return }
        let current = time.seconds
        guard current.isFinite else { return }
        
        if !progress.isTouching && !player.isSeeking {
            progress.sliderValue = Float(current / duration)
        }
        updateTime(current: current, duration: duration)
        
        updateNowPlayingInfo(current: current, duration: duration)
    }
    
}
