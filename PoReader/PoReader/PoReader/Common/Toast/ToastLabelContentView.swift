//
//  ToastLabelContentView.swift
//  MGOA-iOS
//
//  Created by HzS on 2022/3/11.
//

import UIKit

final class ToastLabelContentView: UIView {
    let attribitedString: NSAttributedString
    let config: ToastConfig

    init(attribitedString: NSAttributedString, config: ToastConfig) {
        self.attribitedString = attribitedString
        self.config = config
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            startCountdown()
        }
    }
    
    private func setupUI() {
        layer.cornerRadius = config.cornerRadius
        backgroundColor = config.backgroundColor
        let textLabel = UILabel()
        textLabel.numberOfLines = 0
        textLabel.attributedText = attribitedString
        
        addSubview(textLabel)
        
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        addConstraint(NSLayoutConstraint(item: textLabel, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1, constant: config.paddings.left))
        addConstraint(NSLayoutConstraint(item: textLabel, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: config.paddings.top))
        
        addConstraint(NSLayoutConstraint(item: textLabel, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: -config.paddings.bottom))
        addConstraint(NSLayoutConstraint(item: textLabel, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1, constant: -config.paddings.right))
    }
    
    private func startCountdown() {
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration) {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
                self.alpha = 0.2
            } completion: { finished in
                self.superview?.toastView = nil
                self.removeFromSuperview()
            }
        }
    }
    
}
