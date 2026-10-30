import UIKit

// MARK: - Initializers and fluent configuration
extension PoLabel {
    /// Applies several label changes as one update. Layout invalidation,
    /// contents clearing, and intrinsic-size invalidation are coalesced until
    /// the closure returns.
    @discardableResult
    public func configure(_ updates: (PoLabel) -> Void) -> Self {
        _performConfiguration { updates(self) }
        return self
    }

    /// Creates a label initialized with plain text.
    public convenience init(text: String?, frame: CGRect = .zero) {
        self.init(frame: frame)
        self.text = text
    }

    /// Creates a label initialized with attributed text.
    public convenience init(attributedText: NSAttributedString?, frame: CGRect = .zero) {
        self.init(frame: frame)
        self.attributedText = attributedText
    }

    public convenience init(_ text: String, frame: CGRect = .zero) {
        self.init(frame: frame)
        self.text = text
    }

    public convenience init(_ attributedText: NSAttributedString, frame: CGRect = .zero) {
        self.init(frame: frame)
        self.attributedText = attributedText
    }

    public convenience init(frame: CGRect = .zero,
                            attributeContainer: PoAttributeContainer? = nil,
                            mergePolicy: PoTextStyleMergePolicy = .keepLocal,
                            @PoTextBuilder _ builder: () -> NSAttributedString) {
        self.init(frame: frame)
        setText(attributeContainer: attributeContainer, mergePolicy: mergePolicy, builder)
    }

    public func setText(attributeContainer: PoAttributeContainer? = nil,
                        mergePolicy: PoTextStyleMergePolicy = .keepLocal,
                        @PoTextBuilder _ builder: () -> NSAttributedString) {
        attributedText = NSAttributedString(attributeContainer: attributeContainer,
                                            mergePolicy: mergePolicy,
                                            builder: builder)
    }

    public convenience init(frame: CGRect = .zero,
                            style: PoTextStyle,
                            mergePolicy: PoTextStyleMergePolicy = .keepLocal,
                            @PoTextBuilder _ builder: () -> NSAttributedString) {
        self.init(frame: frame)
        setText(style: style, mergePolicy: mergePolicy, builder)
    }

    public func setText(style: PoTextStyle,
                        mergePolicy: PoTextStyleMergePolicy = .keepLocal,
                        @PoTextBuilder _ builder: () -> NSAttributedString) {
        attributedText = NSAttributedString(style: style,
                                            mergePolicy: mergePolicy) {
            builder()
        }
    }

    @discardableResult
    public func lines(_ numberOfLines: Int) -> Self {
        self.numberOfLines = numberOfLines
        return self
    }

    @discardableResult
    public func alignment(_ alignment: NSTextAlignment) -> Self {
        textAlignment = alignment
        return self
    }

    @discardableResult
    public func verticalAlignment(_ alignment: TextVerticalAlignment) -> Self {
        textVerticalAlignment = alignment
        return self
    }

    @discardableResult
    public func insets(_ insets: UIEdgeInsets) -> Self {
        textContainerInsets = insets
        return self
    }

    @discardableResult
    public func lineBreak(_ mode: NSLineBreakMode) -> Self {
        lineBreakMode = mode
        return self
    }

    @discardableResult
    public func asyncDisplay(_ isDisplayedAsynchronously: Bool) -> Self {
        self.isDisplayedAsynchronously = isDisplayedAsynchronously
        return self
    }

    /// Sets plain text and returns the label for configuration chaining.
    @discardableResult
    public func setText(_ text: String?) -> Self {
        self.text = text
        return self
    }

    /// Sets attributed text and returns the label for configuration chaining.
    @discardableResult
    public func setAttributedText(_ text: NSAttributedString?) -> Self {
        attributedText = text
        return self
    }

    // UIKit-style spellings for callers who prefer property names in a
    // configuration chain. The original short aliases remain source compatible.
    @discardableResult
    public func numberOfLines(_ numberOfLines: Int) -> Self {
        lines(numberOfLines)
    }

    @discardableResult
    public func textAlignment(_ alignment: NSTextAlignment) -> Self {
        self.alignment(alignment)
    }

    @discardableResult
    public func textVerticalAlignment(_ alignment: TextVerticalAlignment) -> Self {
        self.verticalAlignment(alignment)
    }

    @discardableResult
    public func textContainerInsets(_ insets: UIEdgeInsets) -> Self {
        self.insets(insets)
    }

    @discardableResult
    public func lineBreakMode(_ mode: NSLineBreakMode) -> Self {
        self.lineBreak(mode)
    }

    @discardableResult
    public func displaysAsynchronously(_ value: Bool) -> Self {
        self.asyncDisplay(value)
    }
}
