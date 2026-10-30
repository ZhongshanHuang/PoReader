import UIKit

// MARK: - PoAsyncLayerDelegate
extension PoLabel: PoAsyncLayerDelegate {

    func asyncLayerPrepare(_ layer: CALayer) -> PoTextRenderRequest {
        _syncContainerSizeWithBoundsIfNeeded()

        let contentsNeedFade = _state.contentsNeedFade
        _state.contentsNeedFade = false

        let container = _innerContainer
        let verticalAlignment = textVerticalAlignment
        let needsCommitLayout = !isIgnoredCommonProperties &&
            (_state.isLayoutNeedUpdate || (_innerLayout == nil && !_innerText.isEmpty))
        let fadeForAsync = isDisplayedAsynchronously && isFadedOnAsynchronouslyDisplay
        let isHighlighting = _state.showHighlight && _highlight != nil && _highlightRange.location != NSNotFound

        if isHighlighting, let highlight = _highlight {
            let hiText = NSMutableAttributedString(attributedString: _highlightText ?? _innerText)
            for (key, value) in highlight.attributes {
                hiText.po.addAttribute(key, value: value, range: _highlightRange)
            }
            let highlightedLayout = isDisplayedAsynchronously ? nil : TextLayout(attributedString: hiText, container: container)
            let text = highlightedLayout == nil ? hiText : NSAttributedString()
            return PoTextRenderRequest(text: text, container: container,
                                       size: layer.bounds.size, scale: layer.contentsScale, traits: traitCollection,
                                       verticalAlignment: verticalAlignment,
                                       contentsNeedFade: contentsNeedFade, fadeForAsync: fadeForAsync,
                                       layout: highlightedLayout, shouldCommitLayout: false)
        }

        // Build the synchronous layout into the label cache before handing it
        // to the render context. A repeated prepare call can then reuse it.
        if !isDisplayedAsynchronously && !isIgnoredCommonProperties &&
            (needsCommitLayout || (_innerLayout == nil && !_innerText.isEmpty)) {
            _updateIfNeeded()
        }
        let layoutNeedUpdate = _state.isLayoutNeedUpdate
        let layout = !layoutNeedUpdate ? _innerLayout : nil
        let text = layout == nil && !isIgnoredCommonProperties ? _innerText : NSAttributedString()
        return PoTextRenderRequest(text: text, container: container,
                                   size: layer.bounds.size, scale: layer.contentsScale, traits: traitCollection,
                                   verticalAlignment: verticalAlignment,
                                   contentsNeedFade: contentsNeedFade, fadeForAsync: fadeForAsync,
                                   layout: layout, shouldCommitLayout: needsCommitLayout)
    }

    func asyncLayerWillDisplay(_ layer: CALayer, request: PoTextRenderRequest) {
        layer.removeAnimation(forKey: "contents")
    }

    func asyncLayerDidDisplay(_ layer: CALayer, request: PoTextRenderRequest, result: PoTextRenderResult) {
        layer.removeAnimation(forKey: "contents")
        if request.shouldCommitLayout {
            _innerLayout = result.layout
            _state.isLayoutNeedUpdate = false
        }

        // Reconcile hosted objects at commit. Cancelled work must not clear
        // tracking or remove attachments belonging to the displayed bitmap.
        var nextViews = Set<ObjectIdentifier>()
        var nextLayers = Set<ObjectIdentifier>()
        if let layout = result.layout {
            for info in layout.hostedAttachmentInfos {
                switch info.attachment.content {
                case .image: break
                case .view(let view): nextViews.insert(ObjectIdentifier(view))
                case .layer(let layer): nextLayers.insert(ObjectIdentifier(layer))
                }
            }
        }
        for view in _attachmentViews where !nextViews.contains(ObjectIdentifier(view)) {
            if view.superview === self { view.removeFromSuperview() }
        }
        for attachmentLayer in _attachmentLayers where !nextLayers.contains(ObjectIdentifier(attachmentLayer)) {
            if attachmentLayer.superlayer === layer { attachmentLayer.removeFromSuperlayer() }
        }
        let hosted = result.layout?.drawAttachments(in: self, at: result.drawingPoint, size: request.size)
        _attachmentViews = hosted?.views ?? []
        _attachmentLayers = hosted?.layers ?? []

        let duration: TimeInterval
        if request.contentsNeedFade { duration = Constant.highlightFadeDuration }
        else if request.fadeForAsync { duration = Constant.asyncFadeDuration }
        else { return }
        let transition = CATransition()
        transition.duration = duration
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        transition.type = .fade
        layer.add(transition, forKey: "contents")
    }
}
