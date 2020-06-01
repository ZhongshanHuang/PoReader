//
//  ReaderBottomBar.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/20.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

protocol ReaderBottomBarDelegate: class {
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didChangedFontSizeTo result: ReaderBottomBar.FontChangeResult)
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didChangeProgressTo value: Float)
}

extension ReaderBottomBar {
    enum FontChangeResult {
        case smaller
        case bigger
    }
}

class ReaderBottomBar: UIView {
    
    // MARK: - Properties
    weak var delegate: ReaderBottomBarDelegate?
    var progress: Float {
        get { return processView.value }
        set {
            processView.value = newValue
            processLabel.text = String(format: "%.1f%%", newValue * 100)
        }
    }
    
    private lazy var processLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .dynamicColor(light: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6),
                                        dark: UIColor(white: 0.7, alpha: 1))
        label.text = "0.0%"
        return label
    }()
    
    private lazy var processView: UISlider = {
        let progress = PoProgressView()
        progress.addTarget(self, action: #selector(handleProcessViewChanging(_:)), for: .valueChanged)
        progress.addTarget(self, action: #selector(handleProcessChangingDidEnded(_:)), for: .editingDidEnd)
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
        
        // process
        addSubview(processLabel)
        processLabel.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(20)
            make.left.equalToSuperview().offset(10)
            make.width.equalTo(50)
        }
        
        addSubview(processView)
        processView.snp.makeConstraints { (make) in
            make.left.equalTo(processLabel.snp.right).offset(5)
            make.right.equalToSuperview().offset(-20)
            make.centerY.equalTo(processLabel)
        }
        
        // font
        let decreaseFonBtn = UIButton(type: .custom)
        decreaseFonBtn.tag = 666
        decreaseFonBtn.titleLabel?.font = .systemFont(ofSize: 24)
        decreaseFonBtn.setTitle("A-", for: .normal)
        decreaseFonBtn.setTitleColor(UIColor(red: 0, green: 0.48, blue: 1, alpha: 1), for: .normal)
        decreaseFonBtn.setBackgroundImage(UIImage(named: "btn_font_bg"), for: .normal)
        decreaseFonBtn.addTarget(self, action: #selector(fontButtonClick(_:)), for: .touchUpInside)
        addSubview(decreaseFonBtn)
        decreaseFonBtn.snp.makeConstraints { (make) in
            make.top.equalTo(processLabel.snp.bottom).offset(20)
            make.centerX.equalToSuperview().multipliedBy(0.65)
        }
        
        let increaseFonBtn = UIButton(type: .custom)
        increaseFonBtn.tag = 667
        increaseFonBtn.titleLabel?.font = .systemFont(ofSize: 24)
        increaseFonBtn.setTitle("A+", for: .normal)
        increaseFonBtn.setTitleColor(UIColor(red: 0, green: 0.48, blue: 1, alpha: 1), for: .normal)
        increaseFonBtn.setBackgroundImage(UIImage(named: "btn_font_bg"), for: .normal)
        increaseFonBtn.addTarget(self, action: #selector(fontButtonClick(_:)), for: .touchUpInside)
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
    private func handleProcessViewChanging(_ sender: UISlider) {
        processLabel.text = String(format: "%.1f%%", sender.value * 100)
    }
    
    @objc
    private func handleProcessChangingDidEnded(_ sender: UISlider) {
        delegate?.readerBottomBar(self, didChangeProgressTo: sender.value)
    }
    
    @objc
    private func fontButtonClick(_ sender: UIButton) {
        let result: FontChangeResult
        if sender.tag == 666 {
            result = .smaller
        } else {
            result = .bigger
        }
        delegate?.readerBottomBar(self, didChangedFontSizeTo: result)
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
