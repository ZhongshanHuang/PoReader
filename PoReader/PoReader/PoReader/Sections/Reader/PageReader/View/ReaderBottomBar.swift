//
//  ReaderBottomBar.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/20.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

protocol ReaderBottomBarDelegate: AnyObject {
    /// click button
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didClickButton type: ReaderBottomBar.TouchEventType)
    /// touch slider
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didChangeProgressTo value: Float)
}

extension ReaderBottomBar {
    enum TouchEventType: Int {
        case fontDecrease = 1
        case fontIncrease
        case progressForward
        case progressBackward
    }
}

class ReaderBottomBar: UIView {
    
    // MARK: - Properties
    weak var delegate: ReaderBottomBarDelegate?
    var progress: Float {
        get { return progressView.value }
        set {
            progressView.value = newValue
            progressLabel.text = String(format: "%.1f%%", newValue * 100)
        }
    }
    
    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .dynamicColor(light: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6),
                                        dark: UIColor(white: 0.7, alpha: 1))
        label.text = "0.0%"
        return label
    }()
    
    private lazy var progressView: PoProgressView = {
        let progress = PoProgressView()
        progress.addTarget(self, action: #selector(handleProgressViewChanging), for: .valueChanged)
        progress.addTarget(self, action: #selector(handleProgressChangingDidEnded), for: .editingDidEnd)
        return progress
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = Appearance.readerBottomBarBackgroundColor
        
        // process label
        addSubview(progressLabel)
        progressLabel.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(8)
            make.centerX.equalToSuperview()
            make.width.equalTo(50)
        }
        
        // forwardBtn
        let forwardBtn = UIButton(type: .system)
        forwardBtn.setImage(UIImage(systemName: "arrow.backward.square"), for: .normal)
        forwardBtn.addTarget(self, action: #selector(handleButtonClick(_:)), for: .touchUpInside)
        forwardBtn.tag = TouchEventType.progressForward.rawValue
        addSubview(forwardBtn)
        forwardBtn.snp.makeConstraints { (make) in
            make.top.equalTo(progressLabel.snp.bottom).offset(5)
            make.left.equalToSuperview().offset(8)
            make.width.height.equalTo(40)
        }
        
        // backwardBtn
        let backwardBtn = UIButton(type: .system)
        backwardBtn.setImage(UIImage(systemName: "arrow.forward.square"), for: .normal)
        backwardBtn.addTarget(self, action: #selector(handleButtonClick(_:)), for: .touchUpInside)
        backwardBtn.tag = TouchEventType.progressBackward.rawValue
        addSubview(backwardBtn)
        backwardBtn.snp.makeConstraints { (make) in
            make.top.equalTo(progressLabel.snp.bottom).offset(5)
            make.right.equalToSuperview().offset(-8)
            make.width.height.equalTo(40)
        }
        
        // processView
        addSubview(progressView)
        progressView.snp.makeConstraints { (make) in
            make.left.equalTo(forwardBtn.snp.right).offset(8)
            make.right.equalTo(backwardBtn.snp.left).offset(-8)
            make.centerY.equalTo(forwardBtn)
        }
        
        // font
        let decreaseFonBtn = UIButton(type: .custom)
        decreaseFonBtn.tag = TouchEventType.fontDecrease.rawValue
        decreaseFonBtn.titleLabel?.font = .systemFont(ofSize: 24)
        decreaseFonBtn.setTitle("A-", for: .normal)
        decreaseFonBtn.setTitleColor(UIColor(red: 0, green: 0.48, blue: 1, alpha: 1), for: .normal)
        decreaseFonBtn.setBackgroundImage(UIImage(named: "btn_font_bg"), for: .normal)
        decreaseFonBtn.addTarget(self, action: #selector(handleButtonClick), for: .touchUpInside)
        addSubview(decreaseFonBtn)
        decreaseFonBtn.snp.makeConstraints { (make) in
            make.top.equalTo(progressView.snp.bottom).offset(4)
            make.centerX.equalToSuperview().multipliedBy(0.65)
        }
        
        let increaseFonBtn = UIButton(type: .custom)
        increaseFonBtn.tag = TouchEventType.fontIncrease.rawValue
        increaseFonBtn.titleLabel?.font = .systemFont(ofSize: 24)
        increaseFonBtn.setTitle("A+", for: .normal)
        increaseFonBtn.setTitleColor(UIColor(red: 0, green: 0.48, blue: 1, alpha: 1), for: .normal)
        increaseFonBtn.setBackgroundImage(UIImage(named: "btn_font_bg"), for: .normal)
        increaseFonBtn.addTarget(self, action: #selector(handleButtonClick), for: .touchUpInside)
        addSubview(increaseFonBtn)
        increaseFonBtn.snp.makeConstraints { (make) in
            make.top.equalTo(decreaseFonBtn)
            make.centerX.equalToSuperview().multipliedBy(1.35)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 阻断点击事件传递
    }
    
    // MARK: - Selector
    
    @objc
    private func handleProgressViewChanging(_ sender: UISlider) {
        progressLabel.text = String(format: "%.1f%%", sender.value * 100)
    }
    
    @objc
    private func handleProgressChangingDidEnded(_ sender: UISlider) {
        delegate?.readerBottomBar(self, didChangeProgressTo: sender.value)
    }
    
    @objc
    private func handleButtonClick(_ sender: UIButton) {
        if let type = TouchEventType(rawValue: sender.tag) {
            delegate?.readerBottomBar(self, didClickButton: type)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ReaderBottomBar: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

// MARK: - PoProgressView

private final class PoProgressView: UISlider {
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        sendActions(for: .editingDidEnd)
    }
    
}
