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
            let newText = newValue ?? ""
            if _innerText.isEmpty && newText.isEmpty { return }
            if !_innerText.isEmpty && _innerText.string == newText && !_innerText.po.hasDiscontinuousAttributes { return }

            let isNeededAddAttributes = _innerText.isEmpty && !newText.isEmpty
            _innerText.replaceCharacters(in: _innerText.allRange, with: newText)
            _innerText.po.removeDiscontinuousAttributes(in: _innerText.allRange)
            if isNeededAddAttributes {
                _innerText.po.configure { (make) in
                    make.font = _font
                    make.foregroundColor = _textColor
                    make.shadow = _shadowFromProperties()
                    make.alignment = _textAlignment
                }
            }
            _invalidateTextContent(invalidateIntrinsicContentSize: true)
        }
    }

    /// The styled text displayed by the label.
    /// Set a new value to this property also replaces the value of the 'text', 'font', 'textColor', 'textAlignment' and so on.
    public var attributedText: NSAttributedString? {
        get {
            guard !_innerText.isEmpty else { return nil }
            if let _attributedTextSnapshot { return _attributedTextSnapshot }
            let snapshot = _innerText.copy() as? NSAttributedString ?? NSAttributedString(attributedString: _innerText)
            _attributedTextSnapshot = snapshot
            return snapshot
        }
        set {
            guard let newValue, newValue.length > 0 else {
                if _innerText.isEmpty { return }
                _innerText = NSMutableAttributedString()
                if !isIgnoredCommonProperties {
                    _updateOuterTextProperties()
                }
                _invalidateTextContent(invalidateIntrinsicContentSize: true)
                return
            }

            if _innerText === newValue { return }
            if _innerText.length == newValue.length && _innerText.isEqual(to: newValue) { return }

            _innerText = NSMutableAttributedString(attributedString: newValue)
            if _innerText.po.font == nil { _innerText.po.font = _font }

            if !isIgnoredCommonProperties {
                _updateOuterTextProperties()
            }
            _invalidateTextContent(invalidateIntrinsicContentSize: true)
        }
    }

    /// The font of the text.
    var _font: UIFont = UIFont.systemFont(ofSize: 17)
    public var font: UIFont {
        get { return _font }
        set {
            if _font == newValue { return }
            _font = newValue
            _innerText.po.font = newValue
            _invalidateTextContentIfNeeded(invalidateIntrinsicContentSize: true)
        }
    }

    /// The color of the text.
    var _textColor: UIColor = .label
    public var textColor: UIColor {
        get { return _textColor }
        set {
            if _textColor == newValue { return }
            _textColor = newValue
            _innerText.po.foregroundColor = newValue
            _invalidateTextContentIfNeeded(endTouch: false, preservingMeasurement: true)
        }
    }

    /// The shadow color of the text.
    var _shadowColor: UIColor?
    public var shadowColor: UIColor? {
        get { return _shadowColor }
        set {
            if _shadowColor == newValue { return }
            _shadowColor = newValue
            _innerText.po.shadow = _shadowFromProperties()
            _invalidateTextContentIfNeeded(endTouch: false)
        }
    }

    /// The shadow offset of the text.
    var _shadowOffset: CGSize = .zero
    public var shadowOffset: CGSize {
        get { return _shadowOffset }
        set {
            if _shadowOffset == newValue { return }
            _shadowOffset = newValue
            _innerText.po.shadow = _shadowFromProperties()
            _invalidateTextContentIfNeeded(endTouch: false)
        }
    }

    /// The shadow blur of the text.
    var _shadowBlurRadius: CGFloat = -1
    public var shadowBlurRadius: CGFloat {
        get { return _shadowBlurRadius }
        set {
            if _shadowBlurRadius == newValue { return }
            _shadowBlurRadius = newValue
            _innerText.po.shadow = _shadowFromProperties()
            _invalidateTextContentIfNeeded(endTouch: false)
        }
    }

    /// The text horizontal alignment in container.
    var _textAlignment: NSTextAlignment = .natural
    public var textAlignment: NSTextAlignment {
        get { return _textAlignment }
        set {
            if _textAlignment == newValue { return }
            _textAlignment = newValue
            _innerText.po.alignment = newValue
            _invalidateTextContentIfNeeded(invalidateIntrinsicContentSize: true)
        }
    }

    /// The text vertical alignment in container.
    private var _textVerticalAlignment: TextVerticalAlignment = .center
    public var textVerticalAlignment: TextVerticalAlignment {
        get { return _textVerticalAlignment }
        set {
            if _textVerticalAlignment == newValue { return }
            _textVerticalAlignment = newValue
            // Alignment changes only the drawing origin. The glyph layout itself
            // remains valid, so avoid rebuilding TextLayout.
            if _innerLayout != nil || (!_innerText.isEmpty && !isIgnoredCommonProperties) {
                _setLayoutNeedRedraw()
            }
        }
    }

    /// The technique to use for wrapping and truncating the label's text.
    var _lineBreakMode: NSLineBreakMode = .byTruncatingTail
    public var lineBreakMode: NSLineBreakMode {
        get { return _lineBreakMode }
        set {
            if _lineBreakMode == newValue { return }
            _lineBreakMode = newValue

            _innerContainer.lineBreakMode = newValue
            _invalidateTextIfNeeded(invalidateIntrinsicContentSize: true)
        }
    }

    /// The truncation token string used when text is truncated. default is nil, the label use '…' as truncation token.
    var _tailTruncationToken: NSAttributedString?
    public var tailTruncationToken: NSAttributedString? {
        get { return _tailTruncationToken }
        set {
            if _tailTruncationToken === newValue { return }
            _tailTruncationToken = newValue
            _innerContainer.tailTruncationToken = newValue
            _invalidateTextIfNeeded(invalidateIntrinsicContentSize: true)
        }
    }

    /// The maximum number of lines to use for rendering text.
    /// Default is 1, 0 means no limit.
    var _numberOfLines: Int = 1
    public var numberOfLines: Int {
        get { return _numberOfLines }
        set {
            let value = max(0, newValue)
            if _numberOfLines == value { return }
            _numberOfLines = value
            _innerContainer.maximumNumberOfLines = value
            _invalidateTextIfNeeded(invalidateIntrinsicContentSize: true)
        }
    }

    /// The current text layout in text view. set both textLayout and isIgnoredCommonProperties will get best performance
    public var textLayout: TextLayout? {
        get {
            _updateIfNeeded()
            return _innerLayout
        }
        set {
            if let newValue, _innerLayout === newValue { return }
            if newValue == nil, _innerLayout == nil, _innerText.isEmpty { return }
            _layoutRevision &+= 1
            _geometryRevision &+= 1
            _innerLayout = newValue
            _clearMeasurementLayout()
            _attributedTextSnapshot = nil
            _innerText = (newValue?.attributedString.mutableCopy() as? NSMutableAttributedString) ?? NSMutableAttributedString()
            _innerContainer = newValue?.container ?? TextContainer(size: bounds.size)
            if !isIgnoredCommonProperties {
                _updateOuterTextProperties()
                _updateOuterContainerProperties()
            }
            _state.isLayoutNeedUpdate = false
            _clearContentsIfNeeded()
            _setLayoutNeedRedraw()
            _endTouch()
            _requestIntrinsicContentSizeInvalidation()
        }
    }

    /******************************************* text container *******************************************/

    /// An array of UIBezierPath objects representing the exclusion paths inside the receiver's bounding rectangle.
    var _exclusionPaths: [UIBezierPath]?
    public var exclusionPaths: [UIBezierPath]? {
        get { return _exclusionPaths }
        set {
            if _exclusionPaths == newValue { return }
            _exclusionPaths = newValue
            _innerContainer.exclusionPaths = newValue
            _invalidateTextIfNeeded(invalidateIntrinsicContentSize: true)
        }
    }

    /// The insets of the text container's layout area within the text view's content area.
    var _textContainerInsets: UIEdgeInsets = .zero
    public var textContainerInsets: UIEdgeInsets {
        get { return _textContainerInsets }
        set {
            var container = _innerContainer
            container.insets = newValue
            let value = container.insets
            if _textContainerInsets == value { return }
            _textContainerInsets = value
            _innerContainer = container
            _invalidateTextIfNeeded(invalidateIntrinsicContentSize: true)
        }
    }

    /// A concise alias for ``textContainerInsets``.
    public var textInsets: UIEdgeInsets {
        get { textContainerInsets }
        set { textContainerInsets = newValue }
    }

    /// The preferred maximum width for a multiple line label (used by Auto Layout).
    private var _preferredMaxLayoutWidth: CGFloat = 0
    public var preferredMaxLayoutWidth: CGFloat {
        get { _preferredMaxLayoutWidth }
        set {
            let value = newValue.isFinite && newValue > 0 ? newValue : 0
            guard _preferredMaxLayoutWidth != value else { return }
            _preferredMaxLayoutWidth = value
            _layoutRevision &+= 1
            _clearMeasurementLayout()
            _requestIntrinsicContentSizeInvalidation()
        }
    }


    /******************************************* text display *******************************************/

    /// A Boolean value indicating whether layout and rendering run on background threads.
    public var isDisplayedAsynchronously: Bool = true {
        didSet {
            guard oldValue != isDisplayedAsynchronously else { return }
            (layer as? PoAsyncLayer)?.isDisplayedAsynchronously = isDisplayedAsynchronously
            _setLayoutNeedRedraw()
        }
    }

    /// UIKit-style spelling for asynchronous rendering.
    public var displaysAsynchronously: Bool {
        get { isDisplayedAsynchronously }
        set { isDisplayedAsynchronously = newValue }
    }

    /// Clears the previous bitmap and hosted attachments before asynchronous display.
    public var isClearedContentsBeforeAsynchronouslyDisplay: Bool = true

    /// If true and the layer is rendered asynchronously, adds a fade animation when contents change.
    public var isFadedOnAsynchronouslyDisplay: Bool = true

    /// If true, adds a fade animation when a text range becomes highlighted.
    public var isFadedHighlighted: Bool = true

    /// Ignore common properties (such as text, font, textColor, attributedText)
    /// and only use `textLayout` to display content.
    public var isIgnoredCommonProperties: Bool = false {
        didSet {
            guard oldValue != isIgnoredCommonProperties else { return }
            if isIgnoredCommonProperties {
                _endTouch()
                _setLayoutNeedRedraw()
            } else {
                _updateOuterTextProperties()
                _updateOuterContainerProperties()
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
            }
        }
    }



    // MARK: - Properties - [private]

    lazy var _innerText: NSMutableAttributedString = NSMutableAttributedString()
    var _attributedTextSnapshot: NSAttributedString?
    var _innerContainer: TextContainer = TextContainer()
    var _innerLayout: TextLayout?
    /// Only exact-width measurement candidates retain a layout for sizeToFit.
    /// Other measurement queries cache a scalar size, leaving rendering intact.
    var _measurementLayout: TextLayout?
    var _measurementLayoutWidth: CGFloat?
    var _measurementLayoutFittingSize: CGSize?
    var _measurementLayoutRevision: UInt64 = 0
    var _measurementGeometryRevision: UInt64 = 0
    var _layoutRevision: UInt64 = 0
    var _geometryRevision: UInt64 = 0

    lazy var _attachmentViews: [UIView] = []
    lazy var _attachmentLayers: [CALayer] = []

    var _highlightRange: NSRange = NSRange(location: NSNotFound, length: 0)
    var _highlight: TextHighlight?
    var _highlightText: NSAttributedString?

    var _longPressTimer: Timer?
    var _touchBeganPoint: CGPoint = .zero
    var _state: State = State()
    var _configurationDepth = 0
    var _pendingInvalidation: PendingInvalidation = []


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
            _handleGeometryChange(to: newValue.size)
        }
    }

    public override var bounds: CGRect {
        willSet {
            if bounds.size == newValue.size { return }
            _handleGeometryChange(to: newValue.size)
        }
    }

    /// Returns the fitted size without replacing the layout used for rendering.
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        if isIgnoredCommonProperties { return _innerLayout?.suggestedFitsSize() ?? .zero }

        return _measurementSize(forProposedWidth: size.width)
    }

    /// 只有在使用autolayout时才会调用此方法，否则就算调用invalidateIntrinsicContentSize也不会触发
    public override var intrinsicContentSize: CGSize {
        if isIgnoredCommonProperties { return _innerLayout?.suggestedFitsSize() ?? .zero }

        let proposedWidth = bounds.size.width > 0 ? bounds.size.width : TextContainer.maxSize.width
        return _measurementSize(forProposedWidth: proposedWidth)
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            _setLayoutNeedRedraw()
        }
    }

    // MARK: - Touches Handle
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if _handleTouchBegan(at: point) {
            super.touchesBegan(touches, with: event)
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if _handleTouchMoved(to: point) {
            super.touchesMoved(touches, with: event)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if _handleTouchEnded() {
            super.touchesEnded(touches, with: event)
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if _handleTouchCancelled() {
            super.touchesCancelled(touches, with: event)
        }
    }

}
