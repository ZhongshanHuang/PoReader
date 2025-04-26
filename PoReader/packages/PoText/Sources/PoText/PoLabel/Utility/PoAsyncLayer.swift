import UIKit

protocol PoAsyncLayerDelegate: CALayerDelegate {
    
    @MainActor
    func asyncLayerPrepareForRenderCtx() -> PoAsyncLayerRenderCtx
    @MainActor
    func asyncLayerWillDisplay(_ layer: CALayer, renderCtx: PoAsyncLayerRenderCtx)
    func asyncLayerDisplay(renderCtx: PoAsyncLayerRenderCtx, context: CGContext, size: CGSize, isCancelled: @escaping () -> Bool)
    @MainActor
    func asyncLayerDidDisplay(_ layer: CALayer, renderCtx: PoAsyncLayerRenderCtx, finished: Bool)
}

final class PoAsyncLayerRenderCtx: @unchecked Sendable {
    let text: NSAttributedString
    let container: TextContainer
    let verticalAlignment: TextVerticalAlignment
    let layoutNeedUpdate: Bool
    let contentsNeedFade: Bool
    let fadeForAsync: Bool
    let textContainerInsets: UIEdgeInsets
    var layout: TextLayout?
    var layoutUpdated: Bool
    
    init(text: NSAttributedString, container: TextContainer, verticalAlignment: TextVerticalAlignment, layoutNeedUpdate: Bool, contentsNeedFade: Bool, fadeForAsync: Bool, textContainerInsets: UIEdgeInsets, layout: TextLayout? = nil, layoutUpdated: Bool = false) {
        self.text = text
        self.container = container
        self.verticalAlignment = verticalAlignment
        self.layoutNeedUpdate = layoutNeedUpdate
        self.contentsNeedFade = contentsNeedFade
        self.fadeForAsync = fadeForAsync
        self.textContainerInsets = textContainerInsets
        self.layout = layout
        self.layoutUpdated = layoutUpdated
    }
}

final class PoAsyncLayer: CALayer, @unchecked Sendable {
    
    // MARK: - Properties - [public]
    var isDispalyedsAsynchronously: Bool = true
    
    // MARK: - Properties - [private]
    private var _sentinel: PoSentinel = PoSentinel()
    private var renderCtx: PoAsyncLayerRenderCtx?
    
    // MARK: - Methods - [override]
    
    deinit {
        _sentinel.increase()
    }
        
    override class func defaultAction(forKey event: String) -> (any CAAction)? {
        return NSNull()
    }
    
    override class func defaultValue(forKey key: String) -> Any? {
        if key == "isDispalyedsAsynchronously" {
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
        MainActor.assumeIsolated {
            displayAsync(isDispalyedsAsynchronously)
        }
    }
    
    @MainActor
    private func displayAsync(_ isAsync: Bool) {
        guard let asyncDelegate = delegate as? (any PoAsyncLayerDelegate) else { return }
        self.renderCtx = asyncDelegate.asyncLayerPrepareForRenderCtx()
        
        asyncDelegate.asyncLayerWillDisplay(self, renderCtx: self.renderCtx!)
        let size = bounds.size
        if size.width < 1 || size.height < 1 {
            contents = nil
            asyncDelegate.asyncLayerDidDisplay(self, renderCtx: self.renderCtx!, finished: true)
            return
        }

        let value = _sentinel.value()
        let isCancelled: @Sendable () -> Bool = {
            return value != self._sentinel.value()
        }
        
        if isAsync {
            Task(priority: .userInitiated) { @MainActor in
                let image = await drawDisplay(asyncDelegate: asyncDelegate, renderCtx: self.renderCtx!, inSize: size, isCancelled: isCancelled)
                if isCancelled() {
                    asyncDelegate.asyncLayerDidDisplay(self, renderCtx: self.renderCtx!, finished: false)
                    return
                }
                
                self.contents = image?.cgImage
                asyncDelegate.asyncLayerDidDisplay(self, renderCtx: self.renderCtx!, finished: true)
            }
        } else {
            _sentinel.increase()

            let format = UIGraphicsImageRendererFormat.preferred()
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { (ctx) in
                let context = ctx.cgContext
                asyncDelegate.asyncLayerDisplay(renderCtx: self.renderCtx!, context: context, size: size, isCancelled: { false })
            }
            contents = image.cgImage
            asyncDelegate.asyncLayerDidDisplay(self, renderCtx: self.renderCtx!, finished: true)
        }
        
    }
    
    private func drawDisplay(asyncDelegate: any PoAsyncLayerDelegate, renderCtx: PoAsyncLayerRenderCtx, inSize size: CGSize, isCancelled: @escaping () -> Bool) async -> UIImage? {
        if isCancelled() { return nil }

        let format = UIGraphicsImageRendererFormat.preferred()
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { (ctx) in
            let context = ctx.cgContext
            asyncDelegate.asyncLayerDisplay(renderCtx: renderCtx, context: context, size: size, isCancelled: isCancelled)
        }
        return image
    }
    
    private func _cancelAsyncDisplay() {
        _sentinel.increase()
    }
    
    private func _clear() {
        contents = nil
        _cancelAsyncDisplay()
    }
}

