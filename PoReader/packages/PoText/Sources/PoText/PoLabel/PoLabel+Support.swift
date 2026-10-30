import UIKit

// MARK: - Text Lifecycle
extension PoLabel {

    private enum LayoutInvalidationReason {
        case content
        case geometry
    }

    struct PendingInvalidation: OptionSet {
        let rawValue: UInt8

        static let redraw = Self(rawValue: 1 << 0)
        static let clearContents = Self(rawValue: 1 << 1)
        static let intrinsicContentSize = Self(rawValue: 1 << 2)
    }

    func _performConfiguration(_ updates: () -> Void) {
        _configurationDepth += 1
        defer {
            _configurationDepth -= 1
            if _configurationDepth == 0 {
                _flushPendingInvalidation()
            }
        }
        updates()
    }

    private func _flushPendingInvalidation() {
        let pending = _pendingInvalidation
        _pendingInvalidation = []
        if pending.contains(.clearContents) {
            _clearContents()
        }
        if pending.contains(.redraw) {
            layer.setNeedsDisplay()
        }
        if pending.contains(.intrinsicContentSize) {
            invalidateIntrinsicContentSize()
        }
    }

    func _invalidateTextDisplay(endTouch: Bool = true, invalidateIntrinsicContentSize: Bool = false) {
        _invalidateLayout(for: .content)
        if !isIgnoredCommonProperties {
            _clearContentsIfNeeded()
        }
        if endTouch { _endTouch() }
        if invalidateIntrinsicContentSize { _requestIntrinsicContentSizeInvalidation() }
    }

    /// Invalidates the label after its backing attributed string changed.
    /// The cached public getter must be discarded. Paint-only changes can keep
    /// measured geometry while discarding any candidate with stale attributes.
    func _invalidateTextContent(endTouch: Bool = true, invalidateIntrinsicContentSize: Bool = false, preservingMeasurement: Bool = false) {
        _invalidateContentRevision(preservingMeasurement: preservingMeasurement)
        if !isIgnoredCommonProperties {
            _clearContentsIfNeeded()
            _markRenderLayoutAsDirty(redraw: true)
        }
        if endTouch { _endTouch() }
        if invalidateIntrinsicContentSize { _requestIntrinsicContentSizeInvalidation() }
    }

    func _invalidateTextContentIfNeeded(endTouch: Bool = true, invalidateIntrinsicContentSize: Bool = false, preservingMeasurement: Bool = false) {
        guard !_innerText.isEmpty else { return }
        _invalidateTextContent(endTouch: endTouch,
                               invalidateIntrinsicContentSize: invalidateIntrinsicContentSize,
                               preservingMeasurement: preservingMeasurement)
    }

    /// Applies a render invalidation only when common-property rendering is
    /// enabled. This keeps `textLayout` mode independent from the convenience
    /// properties while still invalidating their measurement cache.
    func _invalidateTextIfNeeded(endTouch: Bool = true, invalidateIntrinsicContentSize: Bool = false) {
        guard !_innerText.isEmpty, !isIgnoredCommonProperties else { return }
        _invalidateTextDisplay(endTouch: endTouch,
                               invalidateIntrinsicContentSize: invalidateIntrinsicContentSize)
    }

    func _clearContentsIfNeeded() {
        if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay {
            if _configurationDepth > 0 {
                _pendingInvalidation.insert(.clearContents)
            } else {
                _clearContents()
            }
        }
    }

    func _setLayoutNeedUpdate(clearMeasurement: Bool = true, redraw: Bool = true) {
        _invalidateLayout(for: clearMeasurement ? .content : .geometry, redraw: redraw)
    }

    private func _invalidateLayout(for reason: LayoutInvalidationReason, redraw: Bool = true) {
        switch reason {
        case .content:
            _invalidateContentRevision()
        case .geometry:
            _geometryRevision &+= 1
        }
        _markRenderLayoutAsDirty(redraw: redraw)
    }

    private func _invalidateContentRevision(preservingMeasurement: Bool = false) {
        let hasValidMeasurement = _measurementLayoutFittingSize != nil &&
            _measurementLayoutRevision == _layoutRevision
        _layoutRevision &+= 1
        if preservingMeasurement && hasValidMeasurement {
            // Keep geometry, but never promote a candidate with stale colors.
            _measurementLayout = nil
            _measurementLayoutRevision = _layoutRevision
        } else {
            _clearMeasurementLayout()
        }
        _attributedTextSnapshot = nil
    }

    private func _markRenderLayoutAsDirty(redraw: Bool) {
        _state.isLayoutNeedUpdate = true
        _clearInnerLayout()
        if redraw { _setLayoutNeedRedraw() }
    }

    func _setLayoutNeedRedraw() {
        if _configurationDepth > 0 {
            _pendingInvalidation.insert(.redraw)
        } else {
            layer.setNeedsDisplay()
        }
    }

    func _requestIntrinsicContentSizeInvalidation() {
        if _configurationDepth > 0 {
            _pendingInvalidation.insert(.intrinsicContentSize)
        } else {
            invalidateIntrinsicContentSize()
        }
    }

    func _clearInnerLayout() {
        _innerLayout = nil
    }

    func _clearMeasurementLayout() {
        _measurementLayout = nil
        _measurementLayoutWidth = nil
        _measurementLayoutFittingSize = nil
    }

    /// Updates the render container for a frame/bounds change. Keeping this in
    /// one place prevents the two UIView overrides from drifting apart.
    func _handleGeometryChange(to size: CGSize) {
        let oldContainerSize = _innerContainer.size
        let adoptedMeasurement = _adoptMeasurementLayoutIfPossible(for: size)
        _innerContainer.size = size

        if !adoptedMeasurement,
           oldContainerSize != _innerContainer.size,
           !isIgnoredCommonProperties {
            _setLayoutNeedUpdate(clearMeasurement: false, redraw: false)
        }

        _clearContentsIfNeeded()
        _setLayoutNeedRedraw()
    }

    func _updateIfNeeded() {
        guard !isIgnoredCommonProperties else { return }
        guard _state.isLayoutNeedUpdate || (_innerLayout == nil && !_innerText.isEmpty) else { return }
        _state.isLayoutNeedUpdate = false
        _updateLayout()
    }

    func _updateLayout() {
        _innerLayout = TextLayout(attributedString: _innerText, container: _innerContainer)
    }

    /// Caches a size without preparing drawing metadata. Only exact-width
    /// candidates keep their TextKit graph for the existing sizeToFit promotion.
    func _measurementSize(forProposedWidth proposedWidth: CGFloat) -> CGSize {
        guard !_innerText.isEmpty else { return .zero }

        let requestedWidth: CGFloat
        if preferredMaxLayoutWidth > 0, preferredMaxLayoutWidth.isFinite {
            requestedWidth = preferredMaxLayoutWidth
        } else if proposedWidth > 0, proposedWidth.isFinite {
            requestedWidth = proposedWidth
        } else {
            requestedWidth = TextContainer.maxSize.width
        }

        var measurementContainer = _innerContainer
        measurementContainer.size = CGSize(width: requestedWidth, height: TextContainer.maxSize.height)
        let width = measurementContainer.size.width
        if let fittingSize = _measurementLayoutFittingSize,
           _measurementLayoutWidth == width,
           _measurementLayoutRevision == _layoutRevision {
            _measurementGeometryRevision = _geometryRevision
            return fittingSize
        }

        return autoreleasepool {
            let layout = TextLayout.measurementLayout(attributedString: _innerText, container: measurementContainer)
            let size = layout.suggestedFitsSize()
            _measurementLayout = size.width == width ? layout : nil
            _measurementLayoutWidth = width
            _measurementLayoutFittingSize = size
            _measurementLayoutRevision = _layoutRevision
            _measurementGeometryRevision = _geometryRevision
            return size
        }
    }

    /// Reuses a fresh measurement when UIKit applies the exact size returned
    /// by `sizeThatFits`/`intrinsicContentSize` (the usual `sizeToFit` path).
    /// Any intervening content or geometry change makes the candidate invalid.
    @discardableResult
    func _adoptMeasurementLayoutIfPossible(for size: CGSize) -> Bool {
        guard !isIgnoredCommonProperties,
              !_innerText.isEmpty,
              let measurementLayout = _measurementLayout,
              let fittingSize = _measurementLayoutFittingSize,
              _measurementLayoutRevision == _layoutRevision,
              _measurementGeometryRevision == _geometryRevision,
              fittingSize.width == measurementLayout.container.size.width,
              size == fittingSize else {
            return false
        }

        measurementLayout.prepareForDrawing()
        _innerLayout = measurementLayout
        _innerContainer.size = size
        _state.isLayoutNeedUpdate = false
        _clearMeasurementLayout()
        _geometryRevision &+= 1
        return true
    }

    func _syncContainerSizeWithBoundsIfNeeded() {
        let boundsSize = bounds.size
        if _innerContainer.size == boundsSize { return }

        let oldContainerSize = _innerContainer.size
        _innerContainer.size = boundsSize
        if oldContainerSize != _innerContainer.size && !isIgnoredCommonProperties {
            // A bounds change invalidates the render layout, but a measurement
            // cached for another width is still valid and can be reused.
            _setLayoutNeedUpdate(clearMeasurement: false, redraw: false)
        }
    }

    func _clearContents() {
        layer.contents = nil
        for view in _attachmentViews where view.superview === self { view.removeFromSuperview() }
        for attachmentLayer in _attachmentLayers where attachmentLayer.superlayer === layer {
            attachmentLayer.removeFromSuperlayer()
        }
        _attachmentViews.removeAll(keepingCapacity: true)
        _attachmentLayers.removeAll(keepingCapacity: true)
    }

}

// MARK: - Property Sync
extension PoLabel {

    func _shadowFromProperties() -> NSShadow? {
        if shadowColor == nil || shadowBlurRadius < 0 { return nil }
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowOffset = shadowOffset
        shadow.shadowBlurRadius = shadowBlurRadius
        return shadow
    }

    func _updateOuterTextProperties() {
        _font = _innerText.po.font ?? UIFont.systemFont(ofSize: 17)
        _textColor = _innerText.po.foregroundColor ?? .label
        if !_innerText.isEmpty {
            _textAlignment = _innerText.po.alignment
            _lineBreakMode = _innerText.po.lineBreakMode
        }
        let shadow = _innerText.po.shadow
        _shadowColor = shadow?.shadowColor as? UIColor
        _shadowOffset = shadow?.shadowOffset ?? .zero
        _shadowBlurRadius = shadow?.shadowBlurRadius ?? -1
        _updateOuterLineBreakMode()
        _attributedTextSnapshot = nil
    }

    func _updateOuterContainerProperties() {
        _tailTruncationToken = _innerContainer.tailTruncationToken
        _numberOfLines = _innerContainer.maximumNumberOfLines
        _exclusionPaths = _innerContainer.exclusionPaths
        _textContainerInsets = _innerContainer.insets
        _updateOuterLineBreakMode()
    }

    func _updateOuterLineBreakMode() {
        _lineBreakMode = _innerContainer.lineBreakMode
    }

}

// MARK: - State
extension PoLabel {
    struct State: OptionSet {
        var rawValue: UInt16

        static let isLayoutNeedUpdate = State(rawValue: 1 << 0)
        var isLayoutNeedUpdate: Bool {
            get { contains(.isLayoutNeedUpdate) }
            set { if newValue { insert(.isLayoutNeedUpdate) } else { remove(.isLayoutNeedUpdate) } }
        }
        static let showHighlight = State(rawValue: 1 << 2)
        var showHighlight: Bool {
            get { contains(.showHighlight) }
            set { if newValue { insert(.showHighlight) } else { remove(.showHighlight) } }
        }
        static let trackingTouch = State(rawValue: 1 << 3)
        var trackingTouch: Bool {
            get { contains(.trackingTouch) }
            set { if newValue { insert(.trackingTouch) } else { remove(.trackingTouch) } }
        }
        static let swallowTouch = State(rawValue: 1 << 4)
        var swallowTouch: Bool {
            get { contains(.swallowTouch) }
            set { if newValue { insert(.swallowTouch) } else { remove(.swallowTouch) } }
        }
        static let touchMoved = State(rawValue: 1 << 5)
        var touchMoved: Bool {
            get { contains(.touchMoved) }
            set { if newValue { insert(.touchMoved) } else { remove(.touchMoved) } }
        }
        static let hasTapAction = State(rawValue: 1 << 6)
        var hasTapAction: Bool {
            get { contains(.hasTapAction) }
            set { if newValue { insert(.hasTapAction) } else { remove(.hasTapAction) } }
        }
        static let hasLongPressAction = State(rawValue: 1 << 7)
        var hasLongPressAction: Bool {
            get { contains(.hasLongPressAction) }
            set { if newValue { insert(.hasLongPressAction) } else { remove(.hasLongPressAction) } }
        }
        static let contentsNeedFade = State(rawValue: 1 << 8)
        var contentsNeedFade: Bool {
            get { contains(.contentsNeedFade) }
            set { if newValue { insert(.contentsNeedFade) } else { remove(.contentsNeedFade) } }
        }
        static let longPressTriggered = State(rawValue: 1 << 9)
        var longPressTriggered: Bool {
            get { contains(.longPressTriggered) }
            set { if newValue { insert(.longPressTriggered) } else { remove(.longPressTriggered) } }
        }
    }

    enum Constant {
        static let longPressMiniDuration: TimeInterval = 0.5
        static let longPressAllowableMovement: CGFloat = 9.0
        static let highlightFadeDuration: TimeInterval = 0.15
        static let asyncFadeDuration: TimeInterval = 0.08
    }

}
