//
//  ScrollReaderDisplayCell.swift
//  PoReader
//
//  Created by HzS on 2022/10/20.
//

import UIKit
import SnapKit

final class ScrollReaderDisplayCell: UICollectionViewCell {
    
    static let identifier = "ScrollReaderDisplayCell"
    
    var pageItem: PageItem? {
        didSet {
            if let content = pageItem?.content {
                textLabel.attributedText = NSAttributedString(string: content, attributes: Appearance.attributes)
            }
        }
    }
        
    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(textLabel)
        textLabel.snp.makeConstraints { make in
            let horizenPadding = Appearance.displayRect.origin.x
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: horizenPadding, bottom: 0, right: horizenPadding))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
