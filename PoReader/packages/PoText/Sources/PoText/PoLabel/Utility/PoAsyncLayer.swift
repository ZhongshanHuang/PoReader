import UIKit

@MainActor
protocol PoAsyncLayerDelegate: CALayerDelegate {
    func asyncLayerPrepareForRenderCtx() -> PoAsyncLayerRenderCtx
    func asyncLayerWillDisplay(_ layer: CALayer, renderCtx: PoAsyncLayerRenderCtx)
    nonisolated
    func asyncLayerDisplay(renderCtx: PoAsyncLayerRenderCtx, context: CGContext, size: CGSize)
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
    var isDisplayedAsynchronously: Bool = true
    
    // MARK: - Methods - [override]
        
    override class func defaultAction(forKey event: String) -> (any CAAction)? {
        nil
    }
    
    override class func defaultValue(forKey key: String) -> Any? {
        if key == "isDispalyedsAsynchronously" {
            true
        } else {
            super.defaultValue(forKey: key)
        }
    }
    
    override func setNeedsLayout() {
        _cancelAsyncDisplay()
        super.setNeedsLayout()
    }
    
    override func display() {
        super.contents = super.contents
        
        struct SafeCarrier: Sendable {
            let layer: PoAsyncLayer
        }
        let carrier = SafeCarrier(layer: self)
        let isDisplayedAsynchronously = isDisplayedAsynchronously
        MainActor.assumeIsolated {
            carrier.layer.displayAsync(isDisplayedAsynchronously)
        }
    }
    
    private var asyncTask: Task<Void, Never>?
    @MainActor
    private func displayAsync(_ isAsync: Bool) {
        asyncTask?.cancel()
        guard let asyncDelegate = delegate as? (any PoAsyncLayerDelegate) else { return }
        let renderCtx = asyncDelegate.asyncLayerPrepareForRenderCtx()
        
        asyncDelegate.asyncLayerWillDisplay(self, renderCtx: renderCtx)
        let size = bounds.size
        if size.width < 1 || size.height < 1 {
            contents = nil
            asyncDelegate.asyncLayerDidDisplay(self, renderCtx: renderCtx, finished: true)
            return
        }
        
        if isAsync {
            asyncTask = Task(priority: .userInitiated) {
                do {
                    let image = try await drawDisplay(asyncDelegate: asyncDelegate, renderCtx: renderCtx, inSize: size)
                    if Task.isCancelled {
                        asyncDelegate.asyncLayerDidDisplay(self, renderCtx: renderCtx, finished: false)
                        return
                    }
                    self.contents = image.cgImage
                    asyncDelegate.asyncLayerDidDisplay(self, renderCtx: renderCtx, finished: true)
                } catch {
                    asyncDelegate.asyncLayerDidDisplay(self, renderCtx: renderCtx, finished: false)
                }
            }
        } else {
            let format = UIGraphicsImageRendererFormat.preferred()
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { (ctx) in
                let context = ctx.cgContext
                asyncDelegate.asyncLayerDisplay(renderCtx: renderCtx, context: context, size: size)
            }
            contents = image.cgImage
            asyncDelegate.asyncLayerDidDisplay(self, renderCtx: renderCtx, finished: true)
        }
        
    }
    
#if swift(>=6.1)
    @concurrent
#endif
    nonisolated
    private func drawDisplay(asyncDelegate: any PoAsyncLayerDelegate, renderCtx: PoAsyncLayerRenderCtx, inSize size: CGSize) async throws -> UIImage {
        try Task.checkCancellation()

        let format = UIGraphicsImageRendererFormat.preferred()
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { (ctx) in
            let context = ctx.cgContext
            asyncDelegate.asyncLayerDisplay(renderCtx: renderCtx, context: context, size: size)
        }
        return image
    }
    
    private func _cancelAsyncDisplay() {
        asyncTask?.cancel()
    }
    
    private func _clear() {
        _cancelAsyncDisplay()
        contents = nil
    }
}
