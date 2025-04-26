//
//  UnderlineViewController.swift
//  KitDemo
//
//  Created by iOSer on 2019/8/27.
//  Copyright © 2019 黄中山. All rights reserved.
//

import UIKit
import PoText

class UnderlineViewController: ExampleBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        version2()
    }
    
    private func version1() {
        let text = NSMutableAttributedString(string: "Underline", attributes: [.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 34)])
    
        text.po.underlineStyle = NSUnderlineStyle.single
        text.po.underlineColor = UIColor.red
        
        let label = PoLabel(frame: CGRect(x: 0, y: 0, width: view.frame.width - 20, height: 0))
        label.numberOfLines = 0
        label.attributedText = text
        label.sizeToFit()
        label.center = view.center
        view.addSubview(label)
    }
    
    private func version2() {
        let text = NSAttributedString {
            "Underline".po.asAttributedString()
                .foregroundColor(.black)
                .font(.systemFont(ofSize: 34))
                .underlineStyle(.single)
                .underlineStyleColor(.red)
        }
                
        let label = PoLabel(frame: CGRect(x: 0, y: 0, width: view.frame.width - 20, height: 0))
        label.numberOfLines = 0
        label.attributedText = text
        label.sizeToFit()
        label.center = view.center
        view.addSubview(label)
    }

}
