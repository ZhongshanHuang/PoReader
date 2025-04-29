//
//  UIView+Toast.swift
//  DigitalMuseum
//
//  Created by zhongshan on 2024/7/24.
//

import UIKit

extension UIView {
    
    private enum AssociatedKeys {
        static var toastView: UInt8 = 0
    }
    
    var toastView: UIView? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.toastView) as? UIView }
        set { objc_setAssociatedObject(self, &AssociatedKeys.toastView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    func makeToast(_ toast: String, duration: TimeInterval = 2, position: Toast.Position = .bottom) {
        Toast.show(toast, duration: duration, position: position, upon: self)
    }
    
    func makeToast(_ toast: NSAttributedString, duration: TimeInterval = 2, position: Toast.Position = .bottom) {
        Toast.show(toast, duration: duration, position: position, upon: self)
    }
    
    func hideToast() {
        toastView?.removeFromSuperview()
        toastView = nil
    }
}

