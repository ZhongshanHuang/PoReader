import UIKit

// MARK: - Touch Handling
extension PoLabel {

    func _handleTouchBegan(at point: CGPoint) -> Bool {
        if let highlightContext = _getHighlight(at: point) {
            _highlight = highlightContext.highlight
            _highlightText = highlightContext.text
            _highlightRange = highlightContext.range
        } else {
            _highlight = nil
            _highlightText = nil
            _highlightRange = NSRange(location: NSNotFound, length: 0)
        }
        if _highlight != nil { _showHighlight(animated: true) }

        _state.hasTapAction = _highlight?.tapAction != nil
        _state.hasLongPressAction = _highlight?.longPressAction != nil
        _state.longPressTriggered = false

        if _state.hasTapAction || _state.hasLongPressAction {
            _touchBeganPoint = point
            _state.trackingTouch = true
            _state.swallowTouch = true
            _state.touchMoved = false
            if _state.hasLongPressAction { _startLongPressTimer() }
        } else {
            _state.trackingTouch = false
            _state.swallowTouch = false
            _state.touchMoved = false
        }

        return !_state.swallowTouch
    }

    func _handleTouchMoved(to point: CGPoint) -> Bool {
        if _state.trackingTouch {
            if !_state.touchMoved {
                let moveH = abs(point.x - _touchBeganPoint.x)
                let moveV = abs(point.y - _touchBeganPoint.y)
                if moveH > moveV {
                    if moveH > Constant.longPressAllowableMovement { _state.touchMoved = true }
                } else {
                    if moveV > Constant.longPressAllowableMovement { _state.touchMoved = true }
                }
                if _state.touchMoved {
                    _endLongPressTimer()
                }
            }

            if _state.touchMoved && _highlight != nil {
                let highlightContext = _getHighlight(at: point)
                if highlightContext?.highlight != _highlight {
                    _hideHighlight(animated: isFadedHighlighted)
                }
            }
        }

        return !_state.swallowTouch
    }

    func _handleTouchEnded() -> Bool {
        let shouldForwardTouch = !_state.swallowTouch
        defer {
            _endLongPressTimer()
            _state.trackingTouch = false
            _state.swallowTouch = false
            _state.touchMoved = false
            _state.longPressTriggered = false
        }

        if _highlight != nil {
            if !_state.touchMoved && !_state.longPressTriggered {
                let tapAction = _highlight?.tapAction
                if tapAction != nil {
                    tapAction?(self, _highlightText ?? _innerText, _highlightRange)
                }
            }
            _removeHighlight(animated: isFadedHighlighted)
        }

        return shouldForwardTouch
    }

    func _handleTouchCancelled() -> Bool {
        let shouldForwardTouch = !_state.swallowTouch
        _endTouch()
        _state.swallowTouch = false
        _state.touchMoved = false
        _state.longPressTriggered = false
        return shouldForwardTouch
    }

    func _endTouch() {
        _endLongPressTimer()
        _removeHighlight(animated: true)
        _state.trackingTouch = false
        _state.longPressTriggered = false
    }

}

// MARK: - Highlight
extension PoLabel {

    private struct HighlightContext {
        let highlight: TextHighlight
        let text: NSAttributedString
        let range: NSRange
    }

    private func _getHighlight(at point: CGPoint) -> HighlightContext? {
        _updateIfNeeded()
        guard let layout = _innerLayout, layout.state.contains(.isContainsHighlight) else { return nil }
        let layoutPoint = _convertPointToLayout(point)
        guard let position = layout.textPositionForPoint(layoutPoint) else { return nil }
        if position == NSNotFound { return nil }

        if _canUseOriginalTextForHighlightLookup(at: position, layout: layout) {
            var originalRange = NSRange(location: NSNotFound, length: 0)
            if let highlight = _innerText.attribute(.poHighlight,
                                                    at: position,
                                                    longestEffectiveRange: &originalRange,
                                                    in: _innerText.allRange) as? TextHighlight {
                return HighlightContext(highlight: highlight, text: _innerText, range: originalRange)
            }
            return nil
        }

        let displayText = layout.attributedString
        guard position < displayText.length else { return nil }

        var displayRange = NSRange(location: NSNotFound, length: 0)
        guard let highlight = displayText.attribute(.poHighlight,
                                                    at: position,
                                                    longestEffectiveRange: &displayRange,
                                                    in: displayText.allRange) as? TextHighlight else {
            return nil
        }

        if position < _innerText.length {
            var originalRange = NSRange(location: NSNotFound, length: 0)
            let originalHighlight = _innerText.attribute(.poHighlight,
                                                         at: position,
                                                         longestEffectiveRange: &originalRange,
                                                         in: _innerText.allRange) as? TextHighlight
            if originalHighlight == highlight {
                return HighlightContext(highlight: highlight, text: _innerText, range: originalRange)
            }
        }

        return HighlightContext(highlight: highlight, text: displayText, range: displayRange)
    }

    private func _canUseOriginalTextForHighlightLookup(at position: Int, layout: TextLayout) -> Bool {
        guard position < _innerText.length else { return false }
        guard let truncationInfo = layout.truncationInfo else { return true }
        return position < truncationInfo.characterRange.location
    }

    func _showHighlight(animated: Bool) {
        guard let highlight = _highlight,
              _highlightRange.location != NSNotFound,
              !highlight.attributes.isEmpty else { return }
        _state.showHighlight = true
        _state.contentsNeedFade = animated
        _setLayoutNeedRedraw()
    }

    func _hideHighlight(animated: Bool) {
        if _state.showHighlight {
            _state.showHighlight = false
            _state.contentsNeedFade = animated
            _setLayoutNeedRedraw()
        }
    }

    func _removeHighlight(animated: Bool) {
        _hideHighlight(animated: animated)
        _highlight = nil
        _highlightText = nil
    }

}

// MARK: - Long Press
extension PoLabel {

    func _startLongPressTimer() {
        _longPressTimer?.invalidate()
        _longPressTimer = Timer(timeInterval: Constant.longPressMiniDuration,
                                target: PoWeakProxy(target: self),
                                selector: #selector(_trackDidLongPress),
                                userInfo: nil,
                                repeats: false)
        RunLoop.current.add(_longPressTimer!, forMode: .common)
    }

    func _endLongPressTimer() {
        _longPressTimer?.invalidate()
        _longPressTimer = nil
    }

    @objc
    func _trackDidLongPress() {
        _endLongPressTimer()
        if let highlight = _highlight, let longPressAction = highlight.longPressAction, _highlightRange.location != NSNotFound {
            _state.longPressTriggered = true
            longPressAction(self, _highlightText ?? _innerText, _highlightRange)
            _state.trackingTouch = false
        }
    }

}

// MARK: - Coordinate Conversion
extension PoLabel {

    func _convertPointToLayout(_ point: CGPoint) -> CGPoint {
        guard let boundingSize = _innerLayout?.textBoundingSize else { return .zero }
        var point = point
        point.x -= _textContainerInsets.left
        switch textVerticalAlignment {
        case .center:
            point.y -= (bounds.height - boundingSize.height) * 0.5 + (_textContainerInsets.top - _textContainerInsets.bottom) / 2
        case .bottom:
            point.y -= (bounds.height - boundingSize.height) - _textContainerInsets.bottom
        case .top:
            point.y -= _textContainerInsets.top
        }
        return point
    }

    func _convertPointFromLayout(_ point: CGPoint) -> CGPoint {
        guard let boundingSize = _innerLayout?.textBoundingSize else { return .zero }
        var point = point
        point.x += _textContainerInsets.left
        if boundingSize.height < bounds.height {
            switch textVerticalAlignment {
            case .center:
                point.y += (bounds.height - boundingSize.height) * 0.5 - (_textContainerInsets.top - _textContainerInsets.bottom) / 2
            case .bottom:
                point.y += (bounds.height - boundingSize.height) + _textContainerInsets.bottom
            case .top:
                point.y += _textContainerInsets.top
            }
        }
        return point
    }

    func _convertRectToLayout(_ rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin = _convertPointToLayout(rect.origin)
        return rect
    }

    func _convertRectFromLayout(_ rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin = _convertPointFromLayout(rect.origin)
        return rect
    }

}
