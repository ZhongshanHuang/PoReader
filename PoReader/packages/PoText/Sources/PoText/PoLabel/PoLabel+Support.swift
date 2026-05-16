import UIKit

// MARK: - Text Lifecycle
extension PoLabel {

    func _invalidateTextDisplay(endTouch: Bool = true, invalidateIntrinsicContentSize: Bool = false) {
        _clearContentsIfNeeded()
        _setLayoutNeedUpdate()
        if endTouch { _endTouch() }
        if invalidateIntrinsicContentSize { self.invalidateIntrinsicContentSize() }
    }

    func _clearContentsIfNeeded() {
        if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay {
            _clearContents()
        }
    }

    func _setLayoutNeedUpdate() {
        _state.isLayoutNeedUpdate = true
        _clearInnerLayout()
        _setLayoutNeedRedraw()
    }

    func _setLayoutNeedRedraw() {
        layer.setNeedsDisplay()
    }

    func _clearInnerLayout() {
        _innerLayout = nil
    }

    func _updateIfNeeded() {
        if _state.isLayoutNeedUpdate {
            _state.isLayoutNeedUpdate = false
            _updateLayout()
        }
    }

    func _updateLayout() {
        _innerLayout = TextLayout(attributedString: _innerText, container: _innerContainer)
    }

    func _syncContainerSizeWithBoundsIfNeeded() {
        let boundsSize = bounds.size
        if _innerContainer.size == boundsSize { return }

        _innerContainer.size = boundsSize
        if !isIgnoredCommonProperties {
            _state.isLayoutNeedUpdate = true
            _clearInnerLayout()
        }
    }

    func _clearContents() {
        if layer.contents == nil { return }
        layer.contents = nil
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
        _textColor = _innerText.po.foregroundColor ?? UIColor.black
        if !_innerText.isEmpty {
            _textAlignment = _innerText.po.alignment
            _lineBreakMode = _innerText.po.lineBreakMode
        }
        let shadow = _innerText.po.shadow
        _shadowColor = shadow?.shadowColor as? UIColor
        _shadowOffset = shadow?.shadowOffset ?? .zero
        _shadowBlurRadius = shadow?.shadowBlurRadius ?? -1
        _updateOuterLineBreakMode()
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
        static let updatedSizeThatFits = State(rawValue: 1 << 1)
        var updatedSizeThatFits: Bool {
            get { contains(.updatedSizeThatFits) }
            set { if newValue { insert(.updatedSizeThatFits) } else { remove(.updatedSizeThatFits) } }
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
