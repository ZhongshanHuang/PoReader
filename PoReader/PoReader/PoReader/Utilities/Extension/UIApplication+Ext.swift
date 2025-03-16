//
//  UIApplication+Ext.swift
//  PoReader
//
//  Created by HzS on 2022/11/3.
//

import UIKit

extension UIApplication {
    var currentKeyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).last
        } else if #available(iOS 13.0, *) {
            return connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).last(where: { $0.isKeyWindow })
        } else {
            if let window = delegate?.window {
                return window
            } else {
                return nil
            }
        }
    }
}
