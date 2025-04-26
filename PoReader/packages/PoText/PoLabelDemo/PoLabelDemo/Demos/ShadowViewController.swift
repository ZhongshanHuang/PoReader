//
//  ShadowViewController.swift
//  KitDemo
//
//  Created by iOSer on 2019/8/27.
//  Copyright © 2019 黄中山. All rights reserved.
//

import UIKit
import PoText

class ShadowViewController: ExampleBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        version2()
    }
    
    private func version1() {
        let text = NSMutableAttributedString()
                
        
        let ctShadow = NSMutableAttributedString(string: "Core Text Shadow")
        ctShadow.po.configure { (make) in
            make.font = UIFont.systemFont(ofSize: 30)
            make.foregroundColor = .white
            let shadow = NSShadow()
            shadow.shadowOffset = CGSize(width: 0, height: 2)
            shadow.shadowBlurRadius = 1.5
            shadow.shadowColor = UIColor.gray
            make.shadow = shadow
        }
        text.append(ctShadow)
        text.append(padding)
        
        
        let label = PoLabel()
        label.numberOfLines = 0
        label.frame = view.bounds
        label.attributedText = text
        label.textAlignment = .center
        label.textVerticalAlignment = .center
        view.addSubview(label)
    }
    
    private func version2() {
        let ctShadow = NSShadow()
        ctShadow.shadowOffset = CGSize(width: 0, height: 2)
        ctShadow.shadowBlurRadius = 1.5
        ctShadow.shadowColor = UIColor.gray
        
        let text = NSAttributedString {
            "Core Text Shadow".po.asAttributedString()
                .font(.systemFont(ofSize: 30))
                .foregroundColor(.white)
                .shadow(ctShadow)
        }
        
        let label = PoLabel()
        label.numberOfLines = 0
        label.frame = view.bounds
        label.attributedText = text
        label.textAlignment = .center
        label.textVerticalAlignment = .center
        view.addSubview(label)
    }

}
