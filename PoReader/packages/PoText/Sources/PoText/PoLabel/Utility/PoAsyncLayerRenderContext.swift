import UIKit

final class PoAsyncLayerRenderContext: @unchecked Sendable {
    let text: NSAttributedString
    let container: TextContainer
    let verticalAlignment: TextVerticalAlignment
    let contentsNeedFade: Bool
    let fadeForAsync: Bool
    let textContainerInsets: UIEdgeInsets
    let shouldCommitLayout: Bool
    
    private(set) var layout: TextLayout?

    var hasRenderableContent: Bool {
        !text.isEmpty || layout != nil
    }
    
    init(text: NSAttributedString,
         container: TextContainer,
         verticalAlignment: TextVerticalAlignment,
         contentsNeedFade: Bool,
         fadeForAsync: Bool,
         textContainerInsets: UIEdgeInsets,
         layout: TextLayout? = nil,
         shouldCommitLayout: Bool = false) {
        self.text = text.isEmpty ? NSAttributedString() : (text.copy() as? NSAttributedString ?? text)
        self.container = layout == nil && !text.isEmpty ? container.snapshot() : container
        self.verticalAlignment = verticalAlignment
        self.contentsNeedFade = contentsNeedFade
        self.fadeForAsync = fadeForAsync
        self.textContainerInsets = textContainerInsets
        self.layout = layout
        self.shouldCommitLayout = shouldCommitLayout
    }
    
    func draw(in context: CGContext, size: CGSize) {
        guard let layout = resolveLayout() else { return }
        let point = drawingPoint(for: size, textBoundingSize: layout.textBoundingSize)
        layout.draw(in: context, at: point, size: size)
    }
    
    func drawingPoint(for size: CGSize) -> CGPoint {
        let boundingSize = layout?.textBoundingSize ?? .zero
        return drawingPoint(for: size, textBoundingSize: boundingSize)
    }
    
    @discardableResult
    func resolveLayout() -> TextLayout? {
        if let layout { return layout }
        guard !text.isEmpty else { return nil }
        let resolvedLayout = TextLayout(attributedString: text, container: container)
        layout = resolvedLayout
        return resolvedLayout
    }
    
    private func drawingPoint(for size: CGSize, textBoundingSize: CGSize) -> CGPoint {
        var point = CGPoint(x: textContainerInsets.left, y: 0)
        switch verticalAlignment {
        case .center:
            point.y = (size.height - textBoundingSize.height) * 0.5 + (textContainerInsets.top - textContainerInsets.bottom) / 2
        case .bottom:
            point.y = (size.height - textBoundingSize.height) - textContainerInsets.bottom
        case .top:
            point.y = textContainerInsets.top
        }
        return point.pixelRound
    }
}
