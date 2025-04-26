//
//  CustomTailTruncationTokenViewController.swift
//  PoLabelDemo
//
//  Created by HzS on 2024/9/19.
//

import UIKit
import PoText

class CustomTailTruncationTokenViewController: ExampleBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        version2()
    }
    
    private func version1() {
        let font = UIFont.systemFont(ofSize: 26)
        let text = NSAttributedString(string: "This is how to make custom tail truncation token.This is how to make custom tail truncation token.This is how to make custom tail truncation token", attributes: [.font: font])
        
        let label = PoLabel()
        label.numberOfLines = 0
        label.textVerticalAlignment = .top
        label.size = CGSize(width: 260, height: 100)
        label.center = view.center
        label.attributedText = text
        
        let tokenText = NSMutableAttributedString(string: "...more")
        var hi = TextHighlight()
        hi.foregroundColor = UIColor(red: 0.578, green: 0.79, blue: 1, alpha: 1)
        hi.tapAction = { (_, _, _) in
            print("tap more")
        }
        tokenText.po.setForegroundColor(UIColor(red: 0, green: 0.449, blue: 1, alpha: 1), range: (tokenText.string as NSString).range(of: "more"))
        tokenText.po.textHighlight = hi
        tokenText.po.font = font
        
        let seeMore = PoLabel()
        seeMore.attributedText = tokenText
        seeMore.sizeToFit()
        
        let truncationToken = NSMutableAttributedString.po.attachmentString(with: .view(seeMore), size: seeMore.size, alignToFont: text.po.font!, verticalAlignment: .center)
        label.tailTruncationToken = truncationToken
        
        view.addSubview(label)
    }
    
    private func version2() {
        let font = UIFont.systemFont(ofSize: 26)
        let text = NSAttributedString {
            "This is how to make custom tail truncation token.This is how to make custom tail truncation token.This is how to make custom tail truncation token".po.asAttributedString()
                .font(font)
        }
        
        let label = PoLabel()
        label.numberOfLines = 0
        label.textVerticalAlignment = .top
        label.size = CGSize(width: 260, height: 100)
        label.center = view.center
        label.attributedText = text
        
        var tokenAttributesContainer = PoAttributeContainer()
        tokenAttributesContainer.font = font
        var hi = TextHighlight()
        hi.foregroundColor = UIColor(red: 0.578, green: 0.79, blue: 1, alpha: 1)
        hi.tapAction = { (_, _, _) in
            print("tap more")
        }
        tokenAttributesContainer.textHighlight = hi
        let tokenText = NSMutableAttributedString(attributeContainer: tokenAttributesContainer) {
            String(unicodeScalarLiteral: "\u{2026}").po.asAttributedString()
                .foregroundColor(.black)
            "more".po.asAttributedString()
                .foregroundColor(UIColor(red: 0, green: 0.449, blue: 1, alpha: 1))
        }
        
        let seeMore = PoLabel()
        seeMore.attributedText = tokenText
        seeMore.sizeToFit()
        
        let truncationToken = NSMutableAttributedString.po.attachmentString(with: .view(seeMore), size: seeMore.size, alignToFont: text.po.font!, verticalAlignment: .center)
        label.tailTruncationToken = truncationToken
        view.addSubview(label)
    }
    
}
