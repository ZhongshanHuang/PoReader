import UIKit

@MainActor
protocol PoAsyncLayerDelegate: CALayerDelegate {
    func asyncLayerPrepareForRenderContext() -> PoAsyncLayerRenderContext
    func asyncLayerWillDisplay(_ layer: CALayer, renderContext: PoAsyncLayerRenderContext)
    func asyncLayerDidDisplay(_ layer: CALayer, renderContext: PoAsyncLayerRenderContext, finished: Bool)
}

final class PoAsyncLayer: CALayer, @unchecked Sendable {

    // MARK: - Properties - [public]
    var isDisplayedAsynchronously: Bool = true

    // MARK: - Methods - [override]

    override class func defaultAction(forKey event: String) -> (any CAAction)? {
        nil
    }

    override class func defaultValue(forKey key: String) -> Any? {
        if key == "isDisplayedAsynchronously" {
            true
        } else {
            super.defaultValue(forKey: key)
        }
    }

    override func setNeedsDisplay() {
        _cancelAsyncDisplay()
        super.setNeedsDisplay()
    }

    override func setNeedsDisplay(_ r: CGRect) {
        _cancelAsyncDisplay()
        super.setNeedsDisplay(r)
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
    private var displayGeneration: UInt64 = 0

    @MainActor
    private func displayAsync(_ isAsync: Bool) {
        asyncTask?.cancel()
        guard let asyncDelegate = delegate as? (any PoAsyncLayerDelegate) else { return }
        displayGeneration &+= 1
        let displayGeneration = displayGeneration
        let renderContext = asyncDelegate.asyncLayerPrepareForRenderContext()

        asyncDelegate.asyncLayerWillDisplay(self, renderContext: renderContext)
        let size = bounds.size
        if size.width < 1 || size.height < 1 {
            clearContentsIfNeeded()
            asyncDelegate.asyncLayerDidDisplay(self, renderContext: renderContext, finished: true)
            return
        }
        if !renderContext.hasRenderableContent {
            clearContentsIfNeeded()
            asyncDelegate.asyncLayerDidDisplay(self, renderContext: renderContext, finished: true)
            return
        }

        if isAsync {
            asyncTask = Task(priority: .userInitiated) { [weak self, renderContext, size, displayGeneration] in
                do {
                    let image = try await Self.drawDisplay(renderContext: renderContext, inSize: size)
                    try Task.checkCancellation()
                    guard let self, self.displayGeneration == displayGeneration else { return }
                    self.contents = image.cgImage
                    self.asyncTask = nil
                    guard let asyncDelegate = self.delegate as? (any PoAsyncLayerDelegate) else { return }
                    asyncDelegate.asyncLayerDidDisplay(self, renderContext: renderContext, finished: true)
                } catch {
                    guard let self, self.displayGeneration == displayGeneration else { return }
                    self.asyncTask = nil
                    guard let asyncDelegate = self.delegate as? (any PoAsyncLayerDelegate) else { return }
                    asyncDelegate.asyncLayerDidDisplay(self, renderContext: renderContext, finished: false)
                }
            }
        } else {
            if let image = try? Self.makeImage(renderContext: renderContext, inSize: size) {
                contents = image.cgImage
                asyncDelegate.asyncLayerDidDisplay(self, renderContext: renderContext, finished: true)
            } else {
                asyncDelegate.asyncLayerDidDisplay(self, renderContext: renderContext, finished: false)
            }
        }

    }

#if swift(>=6.1)
    @concurrent
#endif
    nonisolated
    private static func drawDisplay(renderContext: PoAsyncLayerRenderContext, inSize size: CGSize) async throws -> UIImage {
        try makeImage(renderContext: renderContext, inSize: size)
    }

    nonisolated
    private static func makeImage(renderContext: PoAsyncLayerRenderContext, inSize size: CGSize) throws -> UIImage {
        try Task.checkCancellation()

        let format = UIGraphicsImageRendererFormat.preferred()
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { (ctx) in
            let context = ctx.cgContext
            renderContext.draw(in: context, size: size)
        }
        return image
    }

    private func _cancelAsyncDisplay() {
        guard asyncTask != nil else { return }
        asyncTask?.cancel()
        asyncTask = nil
        displayGeneration &+= 1
    }

    private func clearContentsIfNeeded() {
        if contents != nil {
            contents = nil
        }
    }
}
