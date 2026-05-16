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
            if !_innerText.isEmpty && _innerText.string == newText { return }

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
            if !isIgnoredCommonProperties {
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
            }
        }
    }

    /// The styled text displayed by the label.
    /// Set a new value to this property also replaces the value of the 'text', 'font', 'textColor', 'textAlignment' and so on.
    public var attributedText: NSAttributedString? {
        get { return _innerText.isEmpty ? nil : _innerText }
        set {
            guard let newValue, newValue.length > 0 else {
                if _innerText.isEmpty { return }
                _innerText = NSMutableAttributedString()
                if !isIgnoredCommonProperties {
                    _updateOuterTextProperties()
                    _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
                }
                return
            }

            if _innerText === newValue { return }
            if _innerText.length == newValue.length && _innerText.isEqual(to: newValue) { return }

            _innerText = NSMutableAttributedString(attributedString: newValue)
            if _innerText.po.font == nil { _innerText.po.font = _font }

            if !isIgnoredCommonProperties {
                _updateOuterTextProperties()
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
            }
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
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
            }
        }
    }

    /// The color of the text.
    var _textColor: UIColor = {
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
                _invalidateTextDisplay(endTouch: false)
            }
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
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(endTouch: false)
            }
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
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(endTouch: false)
            }
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
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(endTouch: false)
            }
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
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
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
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
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
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
            }
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
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
            }
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
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
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
            invalidateIntrinsicContentSize()
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
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
            }
        }
    }

    /// The insets of the text container's layout area within the text view's content area.
    var _textContainerInsets: UIEdgeInsets = .zero
    public var textContainerInsets: UIEdgeInsets {
        get { return _textContainerInsets }
        set {
            if _textContainerInsets == newValue { return }
            _textContainerInsets = newValue
            _innerContainer.insets = newValue
            if !_innerText.isEmpty && !isIgnoredCommonProperties {
                _invalidateTextDisplay(invalidateIntrinsicContentSize: true)
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

    lazy var _innerText: NSMutableAttributedString = NSMutableAttributedString()
    var _innerContainer: TextContainer = TextContainer()
    var _innerLayout: TextLayout?

    lazy var _attachmentViews: [UIView] = []
    lazy var _attachmentLayers: [CALayer] = []

    var _highlightRange: NSRange = NSRange(location: NSNotFound, length: 0)
    var _highlight: TextHighlight?
    var _highlightText: NSAttributedString?

    var _longPressTimer: Timer?
    var _touchBeganPoint: CGPoint = .zero
    var _state: State = State()


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
            _clearContentsIfNeeded()
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
            _clearContentsIfNeeded()
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
