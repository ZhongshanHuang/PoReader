import UIKit
import AVFoundation
import MediaPlayer

class AudioPlayerView: UIView {
    
    private let player: PoAVPlayer = PoAVPlayer()
    
    private var isPlayToEndTime: Bool = false
    
    private let titleLabel: UILabel = UILabel()
    private let activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .large)
    private let currentTimeLabel: UILabel = UILabel()
    private let durationTimeLabel: UILabel = UILabel()
    private let playButton: UIButton = UIButton(type: .system)
    private let progress: MediaProgressView = MediaProgressView()
    private var isIgnorePeriod: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor(white: 0.5, alpha: 0.7)
        // 名称
        titleLabel.textColor = UIColor.white
        titleLabel.text = "title"
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(5)
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
        }
        
        // 播放/暂停按钮
        playButton.tintColor = .white
        playButton.imageView?.contentMode = .scaleAspectFill
        playButton.setImage(UIImage(systemName: "play.circle"), for: .normal)
        playButton.setImage(UIImage(systemName: "pause.circle"), for: .selected)
        playButton.addTarget(self, action: #selector(AudioPlayerView.playButtonHandle(_:)), for: .touchUpInside)
        addSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.leading.equalTo(titleLabel)
            make.width.height.equalTo(30)
        }
        
        // 当前播放时间
        currentTimeLabel.text = "00:00/00:00"
        currentTimeLabel.textColor = UIColor.white
        currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        currentTimeLabel.textAlignment = .right
        addSubview(currentTimeLabel)
        currentTimeLabel.snp.makeConstraints { make in
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
            make.trailing.equalTo(currentTimeLabel.snp.leading).offset(-5)
            make.centerY.equalTo(playButton)
            make.height.equalTo(20)
        }
        
        // 网络指示器
//        self.addSubview(activityIndicator)
        
        // 总播放时间
//        durationTimeLabel.text = "00:00"
//        durationTimeLabel.textColor = UIColor.white
//        durationTimeLabel.font = UIFont.systemFont(ofSize: 11)
//        addSubview(durationTimeLabel)
    }
    
//    private func _layoutSubviews() {
//        /* ------------------------------topToolBar ------------------------------ */
//        
//        let size = CGSize(width: 45, height: 30)
//        let padding: CGFloat = 8
//        
//        topToolBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 60)
//        
//        // 名称
//        titleLabel.frame = CGRect(x: padding, y: 0, width: topToolBar.bounds.width - 40, height: 60)
//        
//        
//        // 网络指示器
//        activityIndicator.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
//        
//        /* -----------------------------bottomToolBar ----------------------------- */
//        bottomToolBar.frame = CGRect(x: 0, y: bounds.height - 60, width: bounds.width, height: 60)
//        
//        // 播放/暂停按钮
//        let y = (bottomToolBar.bounds.height - size.height)/2
//        
//        playButton.frame = CGRect(x: padding, y: y, width: size.width, height: size.height)
//        
//        // 当前播放时间
//        currentTimeLabel.frame = CGRect(x: playButton.frame.maxX + padding, y: y, width: 60, height: size.height)
//        
//        // 全屏按钮
//        fullScreenButton.frame = CGRect(x: bounds.width - size.width - padding, y: y, width: size.width, height: size.height)
//        
//        // 总时长
//        durationTimeLabel.frame = CGRect(x: fullScreenButton.frame.minX - padding - 60, y: y, width: 60, height: size.height)
//        
//        // 缓冲进度
//        let width: CGFloat = bounds.width - padding - playButton.bounds.width - padding - currentTimeLabel.bounds.width - padding - padding - durationTimeLabel.bounds.width - padding - fullScreenButton.bounds.width - padding
//        
//        progress.frame = CGRect(x: currentTimeLabel.frame.maxX + padding, y: (bottomToolBar.bounds.height - 20)/2, width: width, height: 20)
//    }
    
    // MARK: - selector
    @objc
    private func playButtonHandle(_ sender: UIButton) {
        if player.isPlaying {
            player.pause()
        } else {
            if isPlayToEndTime {
                player.seekToTime(0)
                isPlayToEndTime = false
            } else {
                player.resume()
            }
        }
    }
    
    @objc
    private func progressChangeHandle(_ sender: MediaProgressView) {
        guard let duration = player.duration else { return }
        
        let isPlaying = player.isPlaying
        if isPlaying {
            isIgnorePeriod = true
        }
        
        let target = Double(sender.sliderValue) *  duration
        player.seekToTime(target) { (finished) in
            if finished && isPlaying {
                self.player.resume()
                self.playButton.isSelected = true
                self.isIgnorePeriod = false
            }
        }
    }
    
    // MARK: - helper
    private func formartDuration(_ duration: Double) -> String {
        if duration.isNaN || duration.isInfinite { return "00:00" }
        
        let duration = Int(duration)
        let second = duration % 60
        let minute = duration / 60
        return String(format: "%02d:%02d", minute, second)
    }
}

extension AudioPlayerView {
    private func updateNowPlayingInfo() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        registerRemoteControllEvent()
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
        
        var playingInfo = [String: Any]()
        playingInfo[MPMediaItemPropertyTitle] = "这是title"
        playingInfo[MPMediaItemPropertyAlbumTitle] = "这是AlbumTitle"
        playingInfo[MPMediaItemPropertyPlaybackDuration] = 120
        playingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 10
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = playingInfo
    }
    
    func removeRemote() {
        UIApplication.shared.endReceivingRemoteControlEvents()
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPRemoteCommandCenter.shared().playCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().pauseCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().stopCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().changeRepeatModeCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().changePlaybackRateCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().skipForwardCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().skipBackwardCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().enableLanguageOptionCommand.removeTarget(nil)
    }
    
    public func registerRemoteControllEvent() {
        let remoteCommand = MPRemoteCommandCenter.shared()
        
        remoteCommand.playCommand.addTarget { [weak self] _ in
            guard let self else {
                return .commandFailed
            }
            self.player.resume()
            return .success
        }
        remoteCommand.pauseCommand.addTarget { [weak self] _ in
            guard let self else {
                return .commandFailed
            }
            self.player.pause()
            return .success
        }
        remoteCommand.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else {
                return .commandFailed
            }
            if self.player.isPlaying {
                self.player.pause()
            } else {
                self.player.resume()
            }
            return .success
        }
        remoteCommand.stopCommand.addTarget { [weak self] _ in
            guard let self else {
                return .commandFailed
            }
            self.player.stop()
            return .success
        }
//        remoteCommand.nextTrackCommand.addTarget { [weak self] _ in
//            guard let self else {
//                return .commandFailed
//            }
//            self.nextPlayer()
//            return .success
//        }
//        remoteCommand.previousTrackCommand.addTarget { [weak self] _ in
//            guard let self else {
//                return .commandFailed
//            }
//            self.previousPlayer()
//            return .success
//        }
//        remoteCommand.changeRepeatModeCommand.addTarget { [weak self] event in
//            guard let self, let event = event as? MPChangeRepeatModeCommandEvent else {
//                return .commandFailed
//            }
//            self.options.isLoopPlay = event.repeatType != .off
//            return .success
//        }
//        remoteCommand.changeShuffleModeCommand.isEnabled = false
        // remoteCommand.changeShuffleModeCommand.addTarget {})
//        remoteCommand.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 1, 1.5, 2]
//        remoteCommand.changePlaybackRateCommand.addTarget { [weak self] event in
//            guard let self, let event = event as? MPChangePlaybackRateCommandEvent else {
//                return .commandFailed
//            }
//            self.player.playbackRate = event.playbackRate
//            return .success
//        }
//        remoteCommand.skipForwardCommand.preferredIntervals = [15]
//        remoteCommand.skipForwardCommand.addTarget { [weak self] event in
//            guard let self, let event = event as? MPSkipIntervalCommandEvent else {
//                return .commandFailed
//            }
//            self.seek(time: self.player.currentPlaybackTime + event.interval)
//            return .success
//        }
//        remoteCommand.skipBackwardCommand.preferredIntervals = [15]
//        remoteCommand.skipBackwardCommand.addTarget { [weak self] event in
//            guard let self, let event = event as? MPSkipIntervalCommandEvent else {
//                return .commandFailed
//            }
//            self.seek(time: self.player.currentPlaybackTime - event.interval)
//            return .success
//        }
//        remoteCommand.changePlaybackPositionCommand.addTarget { [weak self] event in
//            guard let self, let event = event as? MPChangePlaybackPositionCommandEvent else {
//                return .commandFailed
//            }
//            self.seek(time: event.positionTime)
//            return .success
//        }
//        remoteCommand.enableLanguageOptionCommand.addTarget { [weak self] event in
//            guard let self, let event = event as? MPChangeLanguageOptionCommandEvent else {
//                return .commandFailed
//            }
//            let selectLang = event.languageOption
//            if selectLang.languageOptionType == .audible,
//               let trackToSelect = self.player.tracks(mediaType: .audio).first(where: { $0.name == selectLang.displayName })
//            {
//                self.player.select(track: trackToSelect)
//            }
//            return .success
//        }
    }
}


// MARK: - PoAVPlayerDelegate
extension AudioPlayerView: PoAVPlayerDelegate {
    
    func avplayerPrepared(_ player: PoAVPlayer) {
        durationTimeLabel.text = formartDuration(player.duration!)
        updateNowPlayingInfo()
    }
    
    func avplayer(_ player: PoAVPlayer, playerItemStatusChanged status: PoAVPlayer.PlaybackStatus) {
        switch status {
        case .idle:
            break
        case .playing:
            playButton.isSelected = true
        case .paused:
            playButton.isSelected = false
        case .finished:
            isPlayToEndTime = true
            playButton.isSelected = false
        case .failed(let error):
            playButton.isSelected = false
            PoDebugLog(error)
        }
    }
    
    /// 缓冲到了哪儿
    func avplayer(_ player: PoAVPlayer, loadedTimeRange range: CMTimeRange) {
        let loaded = range.end.seconds
        let duration = player.duration!
        progress.progressValue = Float(loaded / duration)
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
        let current = time.seconds
        let duration = player.duration!
        if !progress.isTouching && !isIgnorePeriod {
            progress.sliderValue = Float(current / duration)
        }
        currentTimeLabel.text = formartDuration(current)
    }
    
}
