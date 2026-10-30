import UIKit

// MARK: - Style application helpers
extension NSMutableAttributedString {
    func po_applyStyle(_ style: PoTextStyle, mergePolicy: PoTextStyleMergePolicy) {
        po_applyAttributes(style.attributes, mergePolicy: mergePolicy)
    }

    func po_applyAttributes(_ attributes: [NSAttributedString.Key: Any], mergePolicy: PoTextStyleMergePolicy) {
        guard length > 0, !attributes.isEmpty else { return }

        switch mergePolicy {
        case .keepLocal:
            var updates: [(range: NSRange, attributes: [NSAttributedString.Key: Any])] = []
            enumerateAttributes(in: allRange, options: []) { currentAttributes, range, _ in
                var missingAttributes: [NSAttributedString.Key: Any] = [:]
                for (key, value) in attributes where currentAttributes[key] == nil {
                    missingAttributes[key] = value
                }
                if !missingAttributes.isEmpty {
                    updates.append((range, missingAttributes))
                }
            }
            for update in updates {
                addAttributes(update.attributes, range: update.range)
            }
        case .overrideLocal:
            addAttributes(attributes, range: allRange)
        }
    }
}
