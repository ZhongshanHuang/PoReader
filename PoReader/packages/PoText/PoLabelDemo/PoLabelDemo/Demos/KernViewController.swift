//
//  KernViewController.swift
//  KitDemo
//
//  Created by 黄山哥 on 2019/8/27.
//  Copyright © 2019 黄中山. All rights reserved.
//

import UIKit
import PoText

class KernViewController: ExampleBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        version2()
    }
    
    private func version1() {
        let text = NSMutableAttributedString()
        
        do {
            let kern1 = NSMutableAttributedString(string: "Typography Kern -2")
            kern1.po.kern = -2
            text.append(kern1)
            text.append(padding)
            
            let kern2 = NSMutableAttributedString(string: "Typography Kern 0")
            kern2.po.kern = 0
            text.append(kern2)
            text.append(padding)
            
            let kern3 = NSMutableAttributedString(string: "Typography Kern 2")
            kern3.po.kern = 2
            text.append(kern3)
            text.append(padding)
        }
        
        
        let label = PoLabel(frame: CGRect(x: 0, y: 0, width: view.frame.width - 20, height: 0))
        label.numberOfLines = 0
        label.attributedText = text
        label.font = UIFont.systemFont(ofSize: 30)
        label.sizeToFit()
        label.center = view.center
        view.addSubview(label)
    }
    
    private func version2() {
        let text = NSAttributedString {
            "Typography Kern -2".po.asAttributedString()
                .kern(-2)
            
            padding
            
            "Typography Kern 0".po.asAttributedString()
                .kern(0)
            
            padding
            
            "Typography Kern 2".po.asAttributedString()
                .kern(2)

        }
        
        let label = PoLabel(frame: CGRect(x: 0, y: 0, width: view.frame.width - 20, height: 0))
        label.numberOfLines = 0
        label.attributedText = text
        label.font = UIFont.systemFont(ofSize: 30)
        label.sizeToFit()
        label.center = view.center
        view.addSubview(label)
    }
}
