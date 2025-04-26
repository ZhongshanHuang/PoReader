//
//  AttachmentViewController.swift
//  KitDemo
//
//  Created by iOSer on 2019/8/26.
//  Copyright © 2019 黄中山. All rights reserved.
//

import UIKit
import PoText

class AttachmentViewController: ExampleBaseViewController {

    var label: PoLabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        version2()
    }
    
    private func version1() {
        let text = NSMutableAttributedString()
        let font = UIFont.systemFont(ofSize: 16)
        
        do {
            let title = "This is UIImage attachment:"
            text.append(NSAttributedString(string: title))
            
            let image = UIImage(named: "dribbble64_imageio")!
            let attachText = NSAttributedString.po.attachmentString(with: .image(image), alignToFont: font, verticalAlignment: .top)
            text.append(attachText)
            text.append(NSAttributedString(string: "\n"))
        }
        
        do {
            let title = "This is UIView attachment:"
            text.append(NSAttributedString(string: title))
            
            let switcher = UISwitch()
            switcher.sizeToFit()
            
            let attachText = NSMutableAttributedString.po.attachmentString(with: .view(switcher), size: switcher.frame.size, alignToFont: font, verticalAlignment: .center)
            text.append(attachText)
            text.append(NSAttributedString(string: "\n"))
        }
        
        do {
            let title = "This is Animated Image attachment:"
            text.append(NSAttributedString(string: title))
            
            for name in ["001@2x", "022@2x", "019@2x", "056@2x", "085@2x"] {
                guard let path = Bundle.main.path(forResource: name, ofType: "gif") else { continue }
                let image = UIImage(contentsOfFile: path)
                let imageView = UIImageView(image: image)
                let attachText = NSMutableAttributedString.po.attachmentString(with: .view(imageView), size: imageView.size, alignToFont: font, verticalAlignment: .bottom)
                text.append(attachText)
            }
        }
        
        
        text.po.font = font
        
        
        label = PoLabel()
        label.isDisplayedAsynchronously = false
        label.numberOfLines = 0
        label.textVerticalAlignment = .top
        label.size = CGSize(width: 300, height: 260)
        label.center = view.center
        label.attributedText = text
        addSeeMoreButton()
        view.addSubview(label)
        
        label.layer.borderWidth = 0.5
        label.layer.borderColor = UIColor(red: 0, green: 0.436, blue: 1, alpha: 1).cgColor
        
        let dot = newDotView()
        dot.center = CGPoint(x: label.width, y: label.height)
        dot.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        label.addSubview(dot)
        
        let gesture = GestureRecognizer()
        gesture.action = { [weak self] (gesture, state) in
            guard let self = self else { return }
            if state != .moved { return }
            let width = gesture.currentPoint.x
            let height = gesture.currentPoint.y
            self.label.width = width < 30 ? 30 : width
            self.label.height = height < 30 ? 30 : height
        }
        gesture.delegate = self
        label.addGestureRecognizer(gesture)
    }
    
    private func version2() {
        let font = UIFont.systemFont(ofSize: 16)
        let attributeContainer = PoAttributeContainer(attributes: [.font: font])
        
        let text = NSAttributedString(attributeContainer: attributeContainer) {
            "This is UIImage attachment:".po.asAttributedString()
            PoAttachmentString(.image(UIImage(named: "dribbble64_imageio")!), alignToFont: font, verticalAlignment: .top)
            
            "\n".po.asAttributedString()
  
            "This is UIView attachment:".po.asAttributedString()
            
            PoAttachmentString(.view(UISwitch()), size: CGSize(width: 51, height: 31), alignToFont: font, verticalAlignment: .center)
            
            PoAttributedString("\n")
            
            "This is Animated Image attachment:".po.asAttributedString()
            
            for name in ["001@2x", "022@2x", "019@2x", "056@2x", "085@2x"] {
                let image = UIImage(contentsOfFile: Bundle.main.path(forResource: name, ofType: "gif")!)
                let imageView = UIImageView(image: image)
                PoAttachmentString(.view(imageView), size: imageView.size, alignToFont: font, verticalAlignment: .bottom)
            }
        }
                        
        label = PoLabel()
        label.isDisplayedAsynchronously = false
        label.numberOfLines = 0
        label.textVerticalAlignment = .top
        label.size = CGSize(width: 300, height: 260)
        label.center = view.center
        label.attributedText = text
        addSeeMoreButton()
        view.addSubview(label)
        
        label.layer.borderWidth = 0.5
        label.layer.borderColor = UIColor(red: 0, green: 0.436, blue: 1, alpha: 1).cgColor
        
        let dot = newDotView()
        dot.center = CGPoint(x: label.width, y: label.height)
        dot.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        label.addSubview(dot)
        
        let gesture = GestureRecognizer()
        gesture.action = { [weak self] (gesture, state) in
            guard let self = self else { return }
            if state != .moved { return }
            let width = gesture.currentPoint.x
            let height = gesture.currentPoint.y
            self.label.width = width < 30 ? 30 : width
            self.label.height = height < 30 ? 30 : height
        }
        gesture.delegate = self
        label.addGestureRecognizer(gesture)
    }
    
    private func addSeeMoreButton() {
        
        let text = NSMutableAttributedString(string: "\(String(unicodeScalarLiteral: "\u{2026}"))more")
        
        var hi = TextHighlight()
        hi.foregroundColor = UIColor(red: 0.578, green: 0.79, blue: 1, alpha: 1)
        hi.tapAction = { [weak self] (_, _, _) in
            guard let self = self else { return }
            self.label.sizeToFit()
        }
        text.po.setForegroundColor(UIColor(red: 0, green: 0.449, blue: 1, alpha: 1), range: (text.string as NSString).range(of: "more"))
        text.po.setTextHighlight(hi, range: (text.string as NSString).range(of: "more"))
        text.po.font = self.label.font
        
        let seeMore = PoLabel()
        seeMore.attributedText = text
        seeMore.sizeToFit()
        
        let truncationToken = NSMutableAttributedString.po.attachmentString(with: .view(seeMore), size: seeMore.size, alignToFont: text.po.font!, verticalAlignment: .center)
        label.tailTruncationToken = truncationToken
    }
    
    private func newDotView() -> UIView {
        let view = UIView()
        view.size = CGSize(width: 50, height: 50)
        
        let dot = UIView()
        dot.size = CGSize(width: 10, height: 10)
        dot.backgroundColor = UIColor(red: 0, green: 0.463, blue: 1, alpha: 1)
        dot.clipsToBounds = true
        dot.layer.cornerRadius = dot.width / 2
        dot.center = CGPoint(x: view.width / 2, y: view.height / 2)
        view.addSubview(dot)
        
        return view
    }
    
}

extension AttachmentViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let p = gestureRecognizer.location(in: label)
        if p.x < label.width - 40 { return false }
        if p.y < label.height - 40 { return false }
        return true
    }
}
