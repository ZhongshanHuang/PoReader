import Foundation

@resultBuilder
public enum PoAttributedStringBuilder {
    public static func buildBlock() -> NSAttributedString {
        NSAttributedString()
    }

    public static func buildBlock(_ components: NSAttributedString...) -> NSAttributedString {
        let result = components.reduce(into: NSMutableAttributedString()) { result, next in
            result.append(next)
        }
        return result
    }
    
    public static func buildExpression(_ poAttributedString: PoAttributedString) -> NSAttributedString {
        poAttributedString.content
    }
    
    public static func buildExpression(_ poAttachmentString: PoAttachmentString) -> NSAttributedString {
        poAttachmentString.content
    }
    
    public static func buildExpression(_ attributedString: NSAttributedString) -> NSAttributedString {
        attributedString
    }
    
    public static func buildOptional(_ component: NSAttributedString?) -> NSAttributedString {
        component ?? NSAttributedString()
    }

    public static func buildEither(first component: NSAttributedString) -> NSAttributedString {
        component
    }
    
    public static func buildEither(second component: NSAttributedString) -> NSAttributedString {
        component
    }

    public static func buildArray(_ components: [NSAttributedString]) -> NSAttributedString {
        let result = components.reduce(into: NSMutableAttributedString()) { result, next in
            result.append(next)
        }
        return result
    }

    public static func buildLimitedAvailability(_ component: NSAttributedString) -> NSAttributedString {
        component
    }
}

extension NSAttributedString {

    public convenience init(attributeContainer: PoAttributeContainer? = nil, @PoAttributedStringBuilder builder: () -> NSAttributedString) {
        if attributeContainer != nil {
            let param = NSMutableAttributedString(attributedString: builder())
            param.addAttributes(attributeContainer!.attributes, range: param.allRange)
            self.init(attributedString: param)
        } else {
            self.init(attributedString: builder())
        }
    }
    
}

extension NSMutableAttributedString {

    public convenience init(attributeContainer: PoAttributeContainer? = nil, @PoAttributedStringBuilder mbuilder: () -> NSAttributedString) {
        self.init(attributedString: mbuilder())
        if attributeContainer != nil {
            self.addAttributes(attributeContainer!.attributes, range: allRange)
        }
    }
    
}

