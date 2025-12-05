// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

public final class PoLabel: UIView {
    
    // MARK: - Properties - [public]
    
    /// The text displayed by the label.
    /// Set a new value to this property also replaces the text in 'attributedText'.
    /// get the value returns the plain text in 'attributedText'

    public var text: String? {
        get { return _innerText.isEmpty ? nil : _innerText.string }
        set {
            if _innerText.string == newValue { return }
            let isNeededAddAttributes = _innerText.isEmpty && !newValue.isEmpty
            _innerText.replaceCharacters(in: _innerText.allRange, with: newValue ?? "")
            _innerText.po.removeDiscontinuousAttributes(in: _innerText.allRange)
            if isNeededAddAttributes {
                _innerText.po.configure { (make) in
                    make.font = _font
                    make.foregroundColor = _textColor
                    make.shadow = _shadowFromProperties()
                    make.alignment = _textAlignment
                }
            }
            if !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The styled text displayed by the label.
    /// Set a new value to this property also replaces the value of the 'text', 'font', 'textColor', 'textAlignment' and so on.
    public var attributedText: NSAttributedString? {
        get { return _innerText.isEmpty ? nil : _innerText }
        set {
            if _innerText == newValue { return }
            if newValue.isEmpty {
                _innerText = NSMutableAttributedString()
            } else {
                _innerText = newValue!.mutableCopy() as! NSMutableAttributedString
                if _innerText.po.font == nil { _innerText.po.font = _font }
            }

            if !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _updateOuterTextProperties()
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The font of the text.
    private var _font: UIFont = UIFont.systemFont(ofSize: 17)
    public var font: UIFont {
        get { return _font }
        set {
            if _font == newValue { return }
            _font = newValue
            _innerText.po.font = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The color of the text.
    private var _textColor: UIColor = {
        if #available(iOS 13.0, *) {
            return .label
        }
        return .black
    }()
    public var textColor: UIColor {
        get { return _textColor }
        set {
            if _textColor == newValue { return }
            _textColor = newValue
            _innerText.po.foregroundColor = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if !isIgnoredCommonProperties {
                    if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                    _setLayoutNeedUpdate()
                }
            }
        }
    }
    
    /// The shadow color of the text.
    private var _shadowColor: UIColor?
    public var shadowColor: UIColor? {
        get { return _shadowColor }
        set {
            if _shadowColor == newValue { return }
            _shadowColor = newValue
            _innerText.po.shadow = _shadowFromProperties()
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
            }
        }
    }
    
    /// The shadow offset of the text.
    private var _shadowOffset: CGSize = .zero
    public var shadowOffset: CGSize {
        get { return _shadowOffset }
        set {
            if _shadowOffset == newValue { return }
            _shadowOffset = newValue
            _innerText.po.shadow = _shadowFromProperties()
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
            }
        }
    }
    
    /// The shadow blur of the text.
    private var _shadowBlurRadius: CGFloat = -1
    public var shadowBlurRadius: CGFloat {
        get { return _shadowBlurRadius }
        set {
            if _shadowBlurRadius == newValue { return }
            _shadowBlurRadius = newValue
            _innerText.po.shadow = _shadowFromProperties()
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
            }
        }
    }
    
    /// The text horizontal alignment in container.
    private var _textAlignment: NSTextAlignment = .natural
    public var textAlignment: NSTextAlignment {
        get { return _textAlignment }
        set {
            if _textAlignment == newValue { return }
            _textAlignment = newValue
            _innerText.po.alignment = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The text vertical alignment in container.
    private var _textVerticalAlignment: TextVerticalAlignment = .center
    public var textVerticalAlignment: TextVerticalAlignment {
        get { return _textVerticalAlignment }
        set {
            if _textVerticalAlignment == newValue { return }
            _textVerticalAlignment = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The technique to use for wrapping and truncating the label's text.
    private var _lineBreakMode: NSLineBreakMode = .byTruncatingTail
    public var lineBreakMode: NSLineBreakMode {
        get { return _lineBreakMode }
        set {
            if _lineBreakMode == newValue { return }
            _lineBreakMode = newValue
            
            _innerContainer.lineBreakMode = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The truncation token string used when text is truncated. default is nil, the label use '…' as truncation token.
    private var _tailTruncationToken: NSAttributedString?
    public var tailTruncationToken: NSAttributedString? {
        get { return _tailTruncationToken }
        set {
            if _tailTruncationToken === newValue { return }
            _tailTruncationToken = newValue
            _innerContainer.tailTruncationToken = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The maximum number of lines to use for rendering text.
    /// Default is 1, 0 means no limit.
    private var _numberOfLines: Int = 1
    public var numberOfLines: Int {
        get { return _numberOfLines }
        set {
            if _numberOfLines == newValue { return }
            _innerContainer.maximumNumberOfLines = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The current text layout in text view. set both textLayout and isIgnoredCommonProperties will get best performance
    public var textLayout: TextLayout? {
        get {
            _updateIfNeeded()
            return _innerLayout
        }
        set {
            _innerLayout = newValue
            _innerText = (newValue?.textStorage.mutableCopy() as? NSMutableAttributedString) ?? NSMutableAttributedString()
            _innerContainer = newValue?.containter ?? TextContainer(size: bounds.size)
            if !isIgnoredCommonProperties {
                _updateOuterTextProperties()
                _updateOuterContainerProperties()
            }
            if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
            _state.isLayoutNeedUpdate = false
            _setLayoutNeedRedraw()
            _endTouch()
            invalidateIntrinsicContentSize()
        }
    }
    
    /******************************************* text container *******************************************/
        
    /// An array of UIBezierPath objects representing the exclusion paths inside the receiver's bounding rectangle.
    private var _exclusionPaths: [UIBezierPath]?
    public var exclusionPaths: [UIBezierPath]? {
        get { return _exclusionPaths }
        set {
            if _exclusionPaths == newValue { return }
            _exclusionPaths = newValue
            _innerContainer.exclusionPaths = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The insets of the text container's layout area within the text view's content area.
    private var _textContainerInsets: UIEdgeInsets = .zero
    public var textContainerInsets: UIEdgeInsets {
        get { return _textContainerInsets }
        set {
            if _textContainerInsets == newValue { return }
            _textContainerInsets = newValue
            _innerContainer.insets = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay { _clearContents() }
                _setLayoutNeedUpdate()
                _endTouch()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// The preferred maximum width for a multiple line label.(it is valid in autolayout)
    public var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet { invalidateIntrinsicContentSize() }
    }
    
    
    /******************************************* text display *******************************************/
    
    /// A Boolean value indicating whether the layout and rendering codes are running asynchronously on back background threads.
    public var isDisplayedAsynchronously: Bool = true {
        didSet { (layer as! PoAsyncLayer).isDisplayedAsynchronously = isDisplayedAsynchronously }
    }
    
    /// If the value is true, and the layer is rendered asynchronously, then it will set label.layer.contents to nil before display.
    public var isClearedContentsBeforeAsynchronouslyDisplay: Bool = true
    
    /// If the value is ture, and the layer is rendered asynchronously, then it will add a fade animation on layer when the contents of layer changed.
    public var isFadedOnAsynchronouslyDisplay: Bool = true
    
    /// If the value is ture, then it will add a fade animation on layer when some range of text become highlighted.
    public var isFadedHighlighted: Bool = true
    
    /// Ignore common properties (such as text, font, textColor, attributedtext...) and only use 'textLayout' to display content.
    public var isIgnoredCommonProperties: Bool = false
    
    
    
    // MARK: - Properties - [private]
    
    private lazy var _innerText: NSMutableAttributedString = NSMutableAttributedString()
    private var _innerContainer: TextContainer = TextContainer()
    private var _innerLayout: TextLayout?
    
    private lazy var _attachmentViews: [UIView] = []
    private lazy var _attachmentLayers: [CALayer] = []
    
    private var _highlightRange: NSRange = NSRange(location: NSNotFound, length: 0)
    private var _highlight: TextHighlight?
    
    private var _longPressTimer: Timer?
    private var _touchBeganPoint: CGPoint = .zero
    private var _state: State = State()
    
    
    //MARK: - Override
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        _initCommons()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _initCommons()
    }
    
    private func _initCommons() {
        _innerContainer.size = bounds.size
        _innerContainer.insets = _textContainerInsets
        _innerContainer.maximumNumberOfLines = _numberOfLines
        layer.contentsScale = traitCollection.displayScale
    }
    
    deinit {
        MainActor.assumeIsolated {
            _longPressTimer?.invalidate()
        }
    }
    
    public override class var layerClass: AnyClass {
        return PoAsyncLayer.self
    }
    
    public override var frame: CGRect {
        willSet {
            if frame.size == newValue.size { return }
            if _state.updatedSizeThatFits {
                _state.updatedSizeThatFits = false
                return
            }
            _innerContainer.size = newValue.size
            if !isIgnoredCommonProperties {
                _state.isLayoutNeedUpdate = true
            }
            if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay {
                _clearContents()
            }
            _setLayoutNeedRedraw()
        }
    }
    
    public override var bounds: CGRect {
        willSet {
            if bounds.size == newValue.size { return }
            
            _innerContainer.size = newValue.size
            if !isIgnoredCommonProperties {
                _state.isLayoutNeedUpdate = true
            }
            if isDisplayedAsynchronously && isClearedContentsBeforeAsynchronouslyDisplay {
                _clearContents()
            }
            _setLayoutNeedRedraw()
        }
    }
    
    /// 调用sizeToFit时调用此方法
    /// 此方法调用后系统会自动调用frame的set，记住状态这样可以减少一次layout计算
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        if isIgnoredCommonProperties { return _innerLayout?.suggestedFitsSize() ?? .zero }
        
        if preferredMaxLayoutWidth > 0 {
            _innerContainer.size.width = preferredMaxLayoutWidth
        } else {
            _innerContainer.size.width = size.width > 0 ? size.width : TextContainer.maxSize.width
        }
        _innerContainer.size.height = TextContainer.maxSize.height
        
        _updateIfNeeded()
        _state.updatedSizeThatFits = true
        
        return _innerLayout?.suggestedFitsSize() ?? .zero
    }
    
    /// 只有在使用autolayout时才会调用此方法，否则就算调用invalidateIntrinsicContentSize也不会触发
    public override var intrinsicContentSize: CGSize {
        if preferredMaxLayoutWidth > 0 {
            _innerContainer.size.width = preferredMaxLayoutWidth
        } else {
            _innerContainer.size.width = bounds.size.width > 0 ? bounds.size.width : TextContainer.maxSize.width
        }
        _innerContainer.size.height = TextContainer.maxSize.height

        _updateIfNeeded()
        return _innerLayout?.suggestedFitsSize() ?? .zero
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                _setLayoutNeedRedraw()
            }
        }
    }
    
    // MARK: - Touches Handle
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        
        _highlight = _getHighlight(at: point, range: &_highlightRange)
        if _highlight != nil { _showHighlight(animated: true) }
        
        _state.hasTapAction = _highlight?.tapAction != nil
        _state.hasLongPressAction = _highlight?.longPressAction != nil
        
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
        
        if !_state.swallowTouch {
            super.touchesBegan(touches, with: event)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        
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
                let highlight = _getHighlight(at: point, range: nil)
                if highlight != _highlight {
                    _hideHighlight(animated: isFadedHighlighted)
                }
            }
        }
        
        if !_state.swallowTouch {
            super.touchesMoved(touches, with: event)
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if _highlight != nil {
            if !_state.touchMoved {
                let tapAction = _highlight?.tapAction
                if tapAction != nil {
                    tapAction?(self, _innerText, _highlightRange)
                }
            }
            _removeHighlight(animated: isFadedHighlighted)
        }
        
        if !_state.swallowTouch {
            super.touchesEnded(touches, with: event)
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        _endTouch()
        if !_state.swallowTouch {
            super.touchesCancelled(touches, with: event)
        }
    }
    
    // MARK: - Methods - [private]
    
    private func _setLayoutNeedUpdate() {
        _state.isLayoutNeedUpdate = true
        _clearInnerLayout()
        _setLayoutNeedRedraw()
    }
    
    private func _updateIfNeeded() {
        if _state.isLayoutNeedUpdate {
            _state.isLayoutNeedUpdate = false
            _updateLayout()
        }
    }
    
    private func _updateLayout() {
        _innerLayout = TextLayout(attributedString: _innerText, container: _innerContainer)
    }
    
    private func _setLayoutNeedRedraw() {
        layer.setNeedsDisplay()
    }
    
    private func _clearInnerLayout() {
        _innerLayout = nil
    }
    
    private func _startLongPressTimer() {
        _longPressTimer?.invalidate()
        _longPressTimer = Timer(timeInterval: Constant.longPressMiniDuration,
                                target: PoWeakProxy(target: self),
                                selector: #selector(_trackDidLongPress),
                                userInfo: nil,
                                repeats: false)
        RunLoop.current.add(_longPressTimer!, forMode: .common)
    }
    
    private func _endLongPressTimer() {
        _longPressTimer?.invalidate()
        _longPressTimer = nil
    }
    
    @objc
    private func _trackDidLongPress() {
        _endLongPressTimer()
        if let hightlight = _highlight, let longPressAction = hightlight.longPressAction, _highlightRange.location != NSNotFound {
            longPressAction(self, _innerText, _highlightRange)
            _state.trackingTouch = false // 修复长按和单击同时设置了后，长按松开时会调用单击
        }
    }
    
    private func _getHighlight(at point: CGPoint, range: NSRangePointer?) -> TextHighlight? {
        guard _innerLayout?.state.contains(.isContainsHighlight) == true else { return nil }
        let aPoint = _convertPointToLayout(point)
        guard let position = _innerLayout!.textPositionForPoint(aPoint) else { return nil }
        if position == NSNotFound { return nil }
        
        var highlightRange = NSRange(location: NSNotFound, length: 0)
        let highlight = _innerText.attribute(.poHighlight, at: position, longestEffectiveRange: &highlightRange, in: NSRange(location: 0, length: _innerText.length))
        
        if highlight == nil { return nil }
        range?.pointee = highlightRange
        return highlight as? TextHighlight
    }
    
    private func _showHighlight(animated: Bool) {
        if _highlight != nil && _highlightRange.location != NSNotFound {
            _state.showHighlight = true
            _state.contentsNeedFade = animated
            _setLayoutNeedRedraw()
        }
    }
    
    private func _hideHighlight(animated: Bool) {
        if _state.showHighlight {
            _state.showHighlight = false
            _state.contentsNeedFade = animated
            _setLayoutNeedRedraw()
        }
    }
    
    private func _removeHighlight(animated: Bool) {
        _hideHighlight(animated: animated)
        _highlight = nil
    }
    
    private func _endTouch() {
        _endLongPressTimer()
        _removeHighlight(animated: true)
        _state.trackingTouch = false
    }
    

    // MARK: - Coordition convert
    
    private func _convertPointToLayout(_ point: CGPoint) -> CGPoint {
        guard let boundingSize = _innerLayout?.textBoundingSize else { return .zero }
        var point = point
        point.x -= _textContainerInsets.left
        switch textVerticalAlignment {
        case .center:
            point.y -= (self.bounds.height - boundingSize.height) * 0.5 + (_textContainerInsets.top - _textContainerInsets.bottom) / 2
        case .bottom:
            point.y -= (self.bounds.height - boundingSize.height) - _textContainerInsets.bottom
        case .top:
            point.y -= _textContainerInsets.top
        }
        return point
    }
    
    private func _convertPointFromLayout(_ point: CGPoint) -> CGPoint {
        guard let boundingSize = _innerLayout?.textBoundingSize else { return .zero }
        var point = point
        point.x += _textContainerInsets.left
        if boundingSize.height < self.bounds.height {
            switch textVerticalAlignment {
            case .center:
                point.y += (self.bounds.height - boundingSize.height) * 0.5 - (_textContainerInsets.top - _textContainerInsets.bottom) / 2
            case .bottom:
                point.y += (self.bounds.height - boundingSize.height) + _textContainerInsets.bottom
            case .top:
                point.y += _textContainerInsets.top
            }
        }
        return point
    }
    
    private func _convertRectToLayout(_ rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin = _convertPointToLayout(rect.origin)
        return rect
    }
    
    private func _convertRectFromLayout(_ rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin = _convertPointFromLayout(rect.origin)
        return rect
    }
    
    private func _shadowFromProperties() -> NSShadow? {
        if shadowColor == nil || shadowBlurRadius < 0 { return nil }
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowOffset = shadowOffset
        shadow.shadowBlurRadius = shadowBlurRadius
        return shadow
    }
    
    private func _updateOuterTextProperties() {
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
    
    private func _updateOuterContainerProperties() {
        _tailTruncationToken = _innerContainer.tailTruncationToken
        _numberOfLines = _innerContainer.maximumNumberOfLines
        _exclusionPaths = _innerContainer.exclusionPaths
        _textContainerInsets = _innerContainer.insets
        _updateOuterLineBreakMode()
    }
    
    private func _updateOuterLineBreakMode() {
        _lineBreakMode = _innerContainer.lineBreakMode
    }
    
    private func _clearContents() {
        layer.contents = nil
    }
    
}


// MARK: - PoAsyncLayerDelegate
extension PoLabel: PoAsyncLayerDelegate {
    
    func asyncLayerPrepareForRenderCtx() -> PoAsyncLayerRenderCtx {
        let contentsNeedFade = _state.contentsNeedFade
        let text: NSAttributedString = _innerText
        let container = _innerContainer
        let verticalAlignment = textVerticalAlignment
        let layoutNeedUpdate = _state.isLayoutNeedUpdate
        let fadeForAsync = isDisplayedAsynchronously && isFadedOnAsynchronouslyDisplay
        let textContainerInsets = _textContainerInsets
        
        var layout: TextLayout?
        if _state.showHighlight && _highlight != nil {
            let hiText = _innerText.mutableCopy() as! NSMutableAttributedString
            for (key, value) in _highlight!.attributes {
                hiText.po.addAttribute(key, value: value, range: _highlightRange)
            }
            layout = TextLayout(attributedString: hiText, container: _innerContainer)
        } else {
            layout = _innerLayout
        }
        
        return PoAsyncLayerRenderCtx(text: text, container: container, verticalAlignment: verticalAlignment, layoutNeedUpdate: layoutNeedUpdate, contentsNeedFade: contentsNeedFade, fadeForAsync: fadeForAsync, textContainerInsets: textContainerInsets, layout: layout)
    }
    
    func asyncLayerWillDisplay(_ layer: CALayer, renderCtx: PoAsyncLayerRenderCtx) {
        layer.removeAnimation(forKey: "contents")
        
        // if the attachment not in new layout, or we don't know the new layout currently
        // the attachment should be removed.
        for view in self._attachmentViews {
            if renderCtx.layoutNeedUpdate || (renderCtx.layout?.attachmentInfos == nil || renderCtx.layout?.attachmentInfos.contains(where: { $0.key.content == .view(view) }) == false) {
                if view.superview == self {
                    view.removeFromSuperview()
                }
            }
        }
        for layer in self._attachmentLayers {
            if renderCtx.layoutNeedUpdate || (renderCtx.layout?.attachmentInfos == nil || renderCtx.layout?.attachmentInfos.contains(where: { $0.key.content == .layer(layer) }) == false) {
                if layer.superlayer == self.layer {
                    layer.removeFromSuperlayer()
                }
            }
        }
        self._attachmentViews.removeAll()
        self._attachmentLayers.removeAll()
    }
    
    nonisolated
    func asyncLayerDisplay(renderCtx: PoAsyncLayerRenderCtx, context: CGContext, size: CGSize) {
        if renderCtx.text.isEmpty { return }
        
        if renderCtx.layoutNeedUpdate { // 直到此时layout才计算
            renderCtx.layout = TextLayout(attributedString: renderCtx.text, container: renderCtx.container)
            renderCtx.layoutUpdated = true
        }
        
        let boundingSize = renderCtx.layout?.textBoundingSize ?? .zero
        var point = CGPoint(x: renderCtx.textContainerInsets.left, y: 0)
        switch renderCtx.verticalAlignment {
        case .center:
            point.y = (size.height - boundingSize.height) * 0.5 + (renderCtx.textContainerInsets.top - renderCtx.textContainerInsets.bottom) / 2
        case .bottom:
            point.y = (size.height - boundingSize.height) - renderCtx.textContainerInsets.bottom
        case .top:
            point.y = renderCtx.textContainerInsets.top
        }
        point = point.pixelRound // 像素对齐
        
//            layout?.draw(in: context, traitCollection: traitCollection, point: point, size: size, view: nil, layer: nil, cancel: isCancelled)
        renderCtx.layout?.draw(in: context, at: point, size: size)
    }
    
    func asyncLayerDidDisplay(_ layer: CALayer, renderCtx: PoAsyncLayerRenderCtx, finished: Bool) {
        // if the display task is cancelled, we should clear the attachments.
        if finished == false {
            if renderCtx.layout?.attachmentInfos == nil { return }
            for attachment in renderCtx.layout!.attachmentInfos.keys {
                switch attachment.content {
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
        
        guard let view = layer.delegate as? PoLabel else { return }
        if view._state.isLayoutNeedUpdate && renderCtx.layoutUpdated {
            view._innerLayout = renderCtx.layout
            view._state.isLayoutNeedUpdate = false
        }
        
        let size = layer.bounds.size
        let boundingSize = renderCtx.layout?.textBoundingSize ?? .zero
        var point = CGPoint(x: renderCtx.textContainerInsets.left, y: 0)
        switch renderCtx.verticalAlignment {
        case .center:
            point.y = (size.height - boundingSize.height) * 0.5 + (renderCtx.textContainerInsets.top - renderCtx.textContainerInsets.bottom) / 2
        case .bottom:
            point.y = (size.height - boundingSize.height) - renderCtx.textContainerInsets.bottom
        case .top:
            point.y = renderCtx.textContainerInsets.top
        }
        point = point.pixelRound // 像素对齐
        renderCtx.layout?.drawAttachments(in: self, at: point, size: size)
        
        if renderCtx.layout?.attachmentInfos != nil {
            for attachment in renderCtx.layout!.attachmentInfos.keys {
                switch attachment.content {
                case .image:
                    break
                case .view(let uiView):
                    self._attachmentViews.append(uiView)
                case .layer(let cALayer):
                    self._attachmentLayers.append(cALayer)
                }
            }
        }
        
        if renderCtx.contentsNeedFade {
            let transition = CATransition()
            transition.duration = Constant.highlightFadeDuration
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            transition.type = .fade
            layer.add(transition, forKey: "contents")
        } else if renderCtx.fadeForAsync {
            let transition = CATransition()
            transition.duration = Constant.asyncFadeDuration
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            transition.type = .fade
            layer.add(transition, forKey: "contents")
        }
    }
    
}

// MARK: - State
extension PoLabel {
    private struct State: OptionSet {
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
    }
    
    private enum Constant {
        static let longPressMiniDuration: TimeInterval = 0.5
        static let longPressAllowableMovement: CGFloat = 9.0
        static let highlightFadeDuration: TimeInterval = 0.15
        static let asyncFadeDuration: TimeInterval = 0.08
    }
    
}
