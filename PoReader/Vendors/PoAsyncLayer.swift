//
//  PoAsyncLayer.swift
//  KitDemo
//
//  Created by 黄中山 on 2018/5/26.
//  Copyright © 2018年 黄中山. All rights reserved.
//

import UIKit

protocol PoAsyncLayerDelegate: CALayerDelegate {
    func newAsyncDisplayTask() -> PoAsyncLayerDisplayTask
}

class PoAsyncLayerDisplayTask {
    var willDisplay: ((_ layer: CALayer) -> Void)?
    var display: ((_ context: CGContext, _ size: CGSize, _ cancelled: @escaping () -> Bool) -> Void)?
    var didDisplay: ((_ layer: CALayer, _ finished: Bool) -> Void)?
}

private func PoAsyncLayerGetDisplayQueue() -> DispatchQueue {
    return DispatchQueue.global(qos: .userInitiated)
}

final class PoAsyncLayer: CALayer {
    
    // MARK: - Properties - [public]
    var isDispalyedsAsynchronously: Bool = true
    
    // MARK: - Properties - [private]
    private var _sentinel: PoSentinel = PoSentinel()
    
    
    // MARK: - Methods - [override]
    
    override init() {
        super.init()
        contentsScale = UIScreen.main.scale
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        _sentinel.increase()
    }
    
    override class func defaultValue(forKey key: String) -> Any? {
        if key == "dispalysAsynchronously" {
            return true
        } else {
            return super.defaultValue(forKey: key)
        }
    }
    
    override func setNeedsLayout() {
        _cancelAsyncDisplay()
        super.setNeedsLayout()
    }
    
    override func display() {
        super.contents = super.contents
        displayAsync(isDispalyedsAsynchronously)
    }
    
    private func displayAsync(_ async: Bool) {
        guard let asyncDelegate = delegate as? PoAsyncLayerDelegate else { return }
        let task = asyncDelegate.newAsyncDisplayTask()
        if task.display == nil {
            task.willDisplay?(self)
            contents = nil
            task.didDisplay?(self, true)
            return
        }
        
        task.willDisplay?(self)
        let size = bounds.size
        let opaque = isOpaque
        let scale = contentsScale
        let backColor = backgroundColor
        if size.width < 1 || size.height < 1 {
            contents = nil
            task.didDisplay?(self, true)
            return
        }
        
        if async {
            let value = _sentinel.value()
            let isCancelled: () -> Bool = {
                return value != self._sentinel.value()
            }
            
            PoAsyncLayerGetDisplayQueue().async {
                if isCancelled() { return }
                
                var format: UIGraphicsImageRendererFormat
                if #available(iOS 11, *) {
                    format = UIGraphicsImageRendererFormat.preferred()
                } else {
                    format = UIGraphicsImageRendererFormat.default()
                }
                format.opaque = opaque
                let renderer = UIGraphicsImageRenderer(size: size, format: format)
                let image = renderer.image { (rendererCtx) in
                    let context = rendererCtx.cgContext
                    if opaque {
                        context.saveGState()
                        defer { context.restoreGState()}
                        if let color = backColor, color.alpha == 1 {
                            context.setFillColor(color)
                        } else {
                            context.setFillColor(UIColor.white.cgColor)
                        }
                        context.addRect(CGRect(origin: .zero, size: CGSize(width: size.width * scale, height: size.height * scale)))
                        context.fillPath()
                    }
                    
                    task.display?(context, size, isCancelled)
                }
                
                if isCancelled() {
                    DispatchQueue.main.async {
                        task.didDisplay?(self, false)
                    }
                    return
                }
                DispatchQueue.main.async {
                    if isCancelled() {
                        task.didDisplay?(self, false)
                    } else {
                        self.contents = image.cgImage
                        task.didDisplay?(self, true)
                    }
                }
            }
        } else {
            _sentinel.increase()
            
            var format: UIGraphicsImageRendererFormat
            if #available(iOS 11, *) {
                format = UIGraphicsImageRendererFormat.preferred()
            } else {
                format = UIGraphicsImageRendererFormat.default()
            }
            format.opaque = opaque
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { (rendererCtx) in
                let context = rendererCtx.cgContext
                if opaque {
                    context.saveGState()
                    defer { context.restoreGState()}
                    if let color = backColor, color.alpha == 1 {
                        context.setFillColor(color)
                    } else {
                        context.setFillColor(UIColor.white.cgColor)
                    }
                    context.addRect(CGRect(origin: .zero, size: CGSize(width: size.width * scale, height: size.height * scale)))
                    context.fillPath()
                }
                
                task.display?(context, size, { return false })
            }
            contents = image.cgImage
            task.didDisplay?(self, true)
        }
    }
    
    private func _cancelAsyncDisplay() {
        _sentinel.increase()
    }
    
    private func _clear() {
        contents = nil
        _cancelAsyncDisplay()
    }
}

