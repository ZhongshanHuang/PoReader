import UIKit

// MARK: - PoAsyncLayerDelegate
extension PoLabel: PoAsyncLayerDelegate {

    func asyncLayerPrepareForRenderContext() -> PoAsyncLayerRenderContext {
        _syncContainerSizeWithBoundsIfNeeded()

        let contentsNeedFade = _state.contentsNeedFade
        _state.contentsNeedFade = false

        let container = _innerContainer
        let verticalAlignment = textVerticalAlignment
        let layoutNeedUpdate = _state.isLayoutNeedUpdate
        let fadeForAsync = isDisplayedAsynchronously && isFadedOnAsynchronouslyDisplay
        let textContainerInsets = _textContainerInsets
        let isHighlighting = _state.showHighlight && _highlight != nil && _highlightRange.location != NSNotFound

        if isHighlighting, let highlight = _highlight {
            let hiText = NSMutableAttributedString(attributedString: _highlightText ?? _innerText)
            for (key, value) in highlight.attributes {
                hiText.po.addAttribute(key, value: value, range: _highlightRange)
            }
            let highlightedLayout = isDisplayedAsynchronously ? nil : TextLayout(attributedString: hiText, container: container)
            let text = highlightedLayout == nil ? hiText : NSAttributedString()
            return PoAsyncLayerRenderContext(text: text,
                                             container: container,
                                             verticalAlignment: verticalAlignment,
                                             contentsNeedFade: contentsNeedFade,
                                             fadeForAsync: fadeForAsync,
                                             textContainerInsets: textContainerInsets,
                                             layout: highlightedLayout,
                                             shouldCommitLayout: false)
        }

        let reusableLayout = !layoutNeedUpdate ? _innerLayout : nil
        let pendingSynchronousLayout = !isDisplayedAsynchronously && layoutNeedUpdate ? TextLayout(attributedString: _innerText, container: container) : nil
        let layout = reusableLayout ?? pendingSynchronousLayout
        let text = layout == nil ? _innerText : NSAttributedString()
        return PoAsyncLayerRenderContext(text: text,
                                         container: container,
                                         verticalAlignment: verticalAlignment,
                                         contentsNeedFade: contentsNeedFade,
                                         fadeForAsync: fadeForAsync,
                                         textContainerInsets: textContainerInsets,
                                         layout: layout,
                                         shouldCommitLayout: layoutNeedUpdate)
    }

    func asyncLayerWillDisplay(_ layer: CALayer, renderContext: PoAsyncLayerRenderContext) {
        layer.removeAnimation(forKey: "contents")

        guard !_attachmentViews.isEmpty || !_attachmentLayers.isEmpty else { return }

        let hostedAttachmentInfos = renderContext.shouldCommitLayout ? nil : renderContext.layout?.hostedAttachmentInfos
        let shouldRemoveAllAttachments = hostedAttachmentInfos == nil
        var currentAttachmentViews = Set<ObjectIdentifier>()
        var currentAttachmentLayers = Set<ObjectIdentifier>()
        if let hostedAttachmentInfos {
            currentAttachmentViews.reserveCapacity(hostedAttachmentInfos.count)
            currentAttachmentLayers.reserveCapacity(hostedAttachmentInfos.count)
            for info in hostedAttachmentInfos {
                switch info.attachment.content {
                case .image:
                    break
                case .view(let view):
                    currentAttachmentViews.insert(ObjectIdentifier(view))
                case .layer(let layer):
                    currentAttachmentLayers.insert(ObjectIdentifier(layer))
                }
            }
        }

        // if the attachment not in new layout, or we don't know the new layout currently
        // the attachment should be removed.
        for view in _attachmentViews {
            if shouldRemoveAllAttachments || !currentAttachmentViews.contains(ObjectIdentifier(view)) {
                if view.superview == self {
                    view.removeFromSuperview()
                }
            }
        }
        for attachmentLayer in _attachmentLayers {
            if shouldRemoveAllAttachments || !currentAttachmentLayers.contains(ObjectIdentifier(attachmentLayer)) {
                if attachmentLayer.superlayer == self.layer {
                    attachmentLayer.removeFromSuperlayer()
                }
            }
        }
        _attachmentViews.removeAll()
        _attachmentLayers.removeAll()
    }

    func asyncLayerDidDisplay(_ layer: CALayer, renderContext: PoAsyncLayerRenderContext, finished: Bool) {
        // if the display task is cancelled, we should clear the attachments.
        if finished == false {
            guard let layout = renderContext.layout else { return }
            for info in layout.hostedAttachmentInfos {
                switch info.attachment.content {
                case .image:
                    break
                case .view(let uiView):
                    if uiView.superview == (layer.delegate as? UIView) { uiView.removeFromSuperview() }
                case .layer(let cALayer):
                    if cALayer.superlayer == layer { cALayer.removeFromSuperlayer() }
                }
            }
            return
        }

        layer.removeAnimation(forKey: "contents")

        if renderContext.shouldCommitLayout {
            _innerLayout = renderContext.layout
            _state.isLayoutNeedUpdate = false
        }

        if let layout = renderContext.layout, !layout.hostedAttachmentInfos.isEmpty {
            let size = layer.bounds.size
            let point = renderContext.drawingPoint(for: size)
            let drawnAttachments = layout.drawAttachments(in: self, at: point, size: size)
            if !drawnAttachments.views.isEmpty {
                _attachmentViews.append(contentsOf: drawnAttachments.views)
            }
            if !drawnAttachments.layers.isEmpty {
                _attachmentLayers.append(contentsOf: drawnAttachments.layers)
            }
        }

        if renderContext.contentsNeedFade {
            let transition = CATransition()
            transition.duration = Constant.highlightFadeDuration
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            transition.type = .fade
            layer.add(transition, forKey: "contents")
        } else if renderContext.fadeForAsync {
            let transition = CATransition()
            transition.duration = Constant.asyncFadeDuration
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            transition.type = .fade
            layer.add(transition, forKey: "contents")
        }
    }

}
