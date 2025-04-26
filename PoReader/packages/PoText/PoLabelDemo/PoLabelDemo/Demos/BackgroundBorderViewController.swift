//
//  BorderViewController.swift
//  KitDemo
//
//  Created by 黄山哥 on 2019/8/25.
//  Copyright © 2019 黄中山. All rights reserved.
//

import UIKit
import PoText

class BackgroundBorderViewController: ExampleBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        version2()
    }
    
    private func version1() {
        let text = NSMutableAttributedString()
        
        let tags = ["◉red", "◉orange", "◉yellow", "◉green", "◉cyan", "◉blue", "◉purple"]
        let tagStrokeColors = [UIColor.purple,
                               UIColor.blue,
                               UIColor.cyan,
                               UIColor.green,
                               UIColor.yellow,
                               UIColor.orange,
                               UIColor.red]
        let tagFillColors = [UIColor.red,
                             UIColor.orange,
                             UIColor.yellow,
                             UIColor.green,
                             UIColor.cyan,
                             UIColor.blue,
                             UIColor.purple]
        let font = UIFont.boldSystemFont(ofSize: 16)
        
        var i = 0
        while i < tags.count {
            defer { i += 1 }
            let tag = tags[i]
            let tagStrokeColor = tagStrokeColors[i]
            let tagFillColor = tagFillColors[i]
            let tagText = NSMutableAttributedString(string: tag)
            tagText.po.configure { (make) in
                make.insert("   ", at: 0)
                make.append("   ")
                make.font = font
                make.foregroundColor = .white
                var border = TextBorder(fillColor: tagFillColor, cornerRadius: 10, insets: UIEdgeInsets(top: -2, left: -5.5, bottom: -2, right: -8))
                border.strokeWidth = 1
                border.strokeColor = tagStrokeColor
                border.lineJoin = .bevel
                make.setTextBorder(border, range: (tagText.string as NSString).range(of: tag))
            }
            
            text.append(tagText)
        }
        
        
        text.po.lineSpacing = 10

        
        let label = PoLabel()
        label.numberOfLines = 0
        label.frame = view.bounds
        label.attributedText = text
        view.addSubview(label)
    }
    
    private func version2() {
        let tags = ["red", "orange", "yellow", "green", "cyan", "blue", "purple"]
        let tagStrokeColors = [UIColor.purple,
                               UIColor.blue,
                               UIColor.cyan,
                               UIColor.green,
                               UIColor.yellow,
                               UIColor.orange,
                               UIColor.red]
        let tagFillColors = [UIColor.red,
                             UIColor.orange,
                             UIColor.yellow,
                             UIColor.green,
                             UIColor.cyan,
                             UIColor.blue,
                             UIColor.purple]
        let font = UIFont.boldSystemFont(ofSize: 16)
        
        let text = NSMutableAttributedString {
            for (idx, tag) in tags.enumerated() {
                "   ".po.asAttributedString()
                
                tag.po.asAttributedString()
                    .font(font)
                    .foregroundColor(.white)
                    .textBorder(TextBorder(lineStyle: .single, 
                                           lineWidth: 1,
                                           strokeColor: tagStrokeColors[idx],
                                           lineJoin: .bevel,
                                           fillColor: tagFillColors[idx],
                                           cornerRadius: 10,
                                           insets: UIEdgeInsets(top: -2, left: -5.5, bottom: -2, right: -8)))
                
                
                "   ".po.asAttributedString()
            }
        }
        text.po.lineSpacing = 30

        
        let label = PoLabel()
        label.numberOfLines = 0
        label.frame = view.bounds
        label.attributedText = text
        view.addSubview(label)
    }

}
