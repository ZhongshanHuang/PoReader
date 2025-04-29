//
//  Toast.swift
//  MGOA-iOS
//
//  Created by HzS on 2022/3/11.
//

import UIKit

/// 如需配置默认样式，对ToastModel.default进行修改
public struct Toast {
    
    public enum Position {
        case bottom
        case center
    }

    public static func show(_ toast: String, duration: TimeInterval = 2, position: Toast.Position = .bottom, upon: UIView? = nil) {
        var config = ToastConfig.default
        config.duration = duration
        config.position = position
        
        let paragraphstyle = NSMutableParagraphStyle()
        paragraphstyle.alignment = config.textAlignment
        let attributedString = NSAttributedString(string: toast, attributes: [.foregroundColor: config.textColor, .font: config.font, .paragraphStyle: paragraphstyle])
        show(attributedString, config: config, upon: upon)
    }
    
    public static func show(_ attributedToast: NSAttributedString, duration: TimeInterval = 2, position: Toast.Position = .center, upon: UIView? = nil) {
        var config = ToastConfig.default
        config.duration = duration
        config.position = position
        show(attributedToast, config: config, upon: upon)
    }
    
    public static func show(_ attributedToast: NSAttributedString, config: ToastConfig, upon: UIView?) {
        if attributedToast.string.isEmpty { return }
        guard let keyWindow = UIApplication.shared.currentKeyWindow else { return }
        
        let contentLabel = ToastLabelContentView(attribitedString: attributedToast, config: config)
        
        let containerView: UIView = upon ?? keyWindow
        containerView.toastView?.removeFromSuperview()
        containerView.toastView = contentLabel
        containerView.addSubview(contentLabel)
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: config.margins.left).isActive = true
        contentLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true

        switch config.position {
        case .center:
            contentLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        case .bottom:
            var bottom = config.margins.bottom
            if upon == nil {
                bottom += 49
            }
            contentLabel.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -bottom).isActive = true
        }
        
        contentLabel.alpha = 0.1
        contentLabel.superview?.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            contentLabel.alpha = 1
        } completion: { finished in
            
        }
    }

}

