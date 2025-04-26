//
//  HighlightViewController.swift
//  KitDemo
//
//  Created by iOSer on 2019/8/27.
//  Copyright © 2019 黄中山. All rights reserved.
//

import UIKit
import PoText

class HighlightViewController: ExampleBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
//        version1()
        version2()
    }
    
    func version1() {
        let text = NSMutableAttributedString()
        
        let linkText1 = NSMutableAttributedString(string: "link1-link2")
        linkText1.po.configure { (make) in
            make.font = UIFont.systemFont(ofSize: 30)
            make.underlineStyle = NSUnderlineStyle.single
            make.underlineColor = .blue
            make.foregroundColor = .blue
            
            let hl1 = TextHighlight(backgroundColor: .red) { containerView, text, range in
                print("link1 tap")
            }
            make.setTextHighlight(hl1, range: NSRange(location: 0, length: 5))
            
            let hl2 = TextHighlight(foregroundColor: .yellow) { containerView, text, range in
                print("link2 tap")
            }
            make.setTextHighlight(hl2, range: NSRange(location: 6, length: 5))
        }
        text.append(linkText1)
        
        let label = PoLabel()
        label.numberOfLines = 0
        label.frame = view.bounds
        label.attributedText = text
        label.textAlignment = .center
        label.textVerticalAlignment = .center
        view.addSubview(label)
    }
    
    func version2() {
        let text = NSMutableAttributedString()
        
        let subText1CommonAttributes = PoAttributeContainer()
            .font(.systemFont(ofSize: 30))
            .foregroundColor(.blue)
            .underlineStyle(.single)
            .underlineStyleColor(.blue)
        
        let subText1 = NSMutableAttributedString(attributeContainer: subText1CommonAttributes) {
            "link1".po.asAttributedString()
                .textHighlight(TextHighlight(backgroundColor: .red, tapAction: { containerView, text, range in
                    print("link1 tap")
                }))
            "-".po.asAttributedString()
            "link2".po.asAttributedString()
                .textHighlight(TextHighlight(foregroundColor: .yellow, tapAction: { containerView, text, range in
                    print("link2 tap")
                }))
        }
        text.append(subText1)
        
        
        let label = PoLabel()
        label.numberOfLines = 0
        label.frame = view.bounds
        label.attributedText = text
        label.textAlignment = .center
        label.textVerticalAlignment = .center
        view.addSubview(label)
    }

}
