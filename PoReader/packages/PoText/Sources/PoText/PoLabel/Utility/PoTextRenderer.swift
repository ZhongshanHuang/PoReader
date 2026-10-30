import UIKit

/// Foundation attribute values may contain references. The snapshot owns the
/// string and container; callers must not mutate custom attribute objects while
/// they are in use. UIKit views/layers in attachments are hosted on MainActor.
struct PoTextLayoutSnapshot: @unchecked Sendable {
    let text: NSAttributedString
    let container: TextContainer

    init(text: NSAttributedString, container: TextContainer) {
        self.text = NSAttributedString(attributedString: text)
        self.container = container.snapshot()
    }
}

enum PoTextRenderSource: Sendable {
    case empty
    case text(PoTextLayoutSnapshot)
    case layout(TextLayout)
}

struct PoTextRenderRequest: Sendable {
    let source: PoTextRenderSource
    let size: CGSize
    let scale: CGFloat
    let traits: UITraitCollection
    let verticalAlignment: TextVerticalAlignment
    let insets: UIEdgeInsets
    let shouldCommitLayout: Bool
    let contentsNeedFade: Bool
    let fadeForAsync: Bool

    init(text: NSAttributedString, container: TextContainer,
         size: CGSize, scale: CGFloat, traits: UITraitCollection = UITraitCollection(),
         verticalAlignment: TextVerticalAlignment,
         contentsNeedFade: Bool, fadeForAsync: Bool,
         layout: TextLayout? = nil, shouldCommitLayout: Bool = false) {
        if let layout {
            source = .layout(layout)
        } else if text.length > 0 {
            source = .text(PoTextLayoutSnapshot(text: text, container: container))
        } else {
            source = .empty
        }
        self.size = size
        self.scale = scale > 0 && scale.isFinite ? scale : 1
        self.traits = traits
        self.verticalAlignment = verticalAlignment
        insets = container.insets
        self.shouldCommitLayout = shouldCommitLayout
        self.contentsNeedFade = contentsNeedFade
        self.fadeForAsync = fadeForAsync
    }

    func drawingPoint(for layout: TextLayout?) -> CGPoint {
        let height = layout?.textBoundingSize.height ?? 0
        let y: CGFloat
        switch verticalAlignment {
        case .center: y = (size.height - height + insets.top - insets.bottom) * 0.5
        case .bottom: y = size.height - height - insets.bottom
        case .top: y = insets.top
        }
        return CGPoint(x: (insets.left * scale).rounded() / scale,
                       y: (y * scale).rounded() / scale)
    }
}

struct PoTextRenderResult: Sendable {
    let image: UIImage?
    let layout: TextLayout?
    let drawingPoint: CGPoint
}

/// One worker per layer serializes its CPU work. Cancelled requests waiting on
/// the actor exit before layout/allocation; different labels can run in parallel
/// on Swift's executor. Attachment references stay stable; UI hosting and
/// delegate callbacks occur only on MainActor.
actor PoTextRenderer {
    func render(_ request: PoTextRenderRequest) throws -> PoTextRenderResult {
        try Self.renderImmediately(request)
    }

    nonisolated static func renderImmediately(_ request: PoTextRenderRequest) throws -> PoTextRenderResult {
        try Task.checkCancellation()
        guard request.size.width >= 1, request.size.height >= 1 else {
            return PoTextRenderResult(image: nil, layout: nil, drawingPoint: .zero)
        }
        return try autoreleasepool {
            let layout: TextLayout
            switch request.source {
            case .empty:
                return PoTextRenderResult(image: nil, layout: nil, drawingPoint: .zero)
            case .layout(let cached):
                layout = cached
            case .text(let snapshot):
                layout = TextLayout(attributedString: snapshot.text, container: snapshot.container)
            }
            try Task.checkCancellation()
            let point = request.drawingPoint(for: layout)
            let format = UIGraphicsImageRendererFormat.preferred()
            format.scale = request.scale
            let renderer = UIGraphicsImageRenderer(size: request.size, format: format)
            let image = renderer.image { context in
                request.traits.performAsCurrent {
                    layout.draw(in: context.cgContext, at: point, size: request.size)
                }
            }
            try Task.checkCancellation()
            return PoTextRenderResult(image: image, layout: layout, drawingPoint: point)
        }
    }
}
