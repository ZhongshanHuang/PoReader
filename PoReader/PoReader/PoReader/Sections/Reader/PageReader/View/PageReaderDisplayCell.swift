//
//  PageReaderDisplayCell.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/18.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

class PageReaderDisplayCell: UIViewController {

    let pageItem: PageItem
        
    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "H:mm"
        return dateFormatter
    }()
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10)
        label.textColor = Appearance.readerOtherColor
        return label
    }()
    
    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10)
        label.textColor = Appearance.readerOtherColor
        return label
    }()
    
    init(pageItem: PageItem) {
        self.pageItem = pageItem
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = TextDisplayView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = Appearance.readerBackgroundColor
        (view as! TextDisplayView).attributedString = NSAttributedString(string: pageItem.content, attributes: Appearance.attributes)
        
        
        var bottomMargin: CGFloat = UIApplication.shared.currentKeyWindow?.safeAreaInsets.bottom ?? 0
        if bottomMargin == 0 {
            bottomMargin = 10
        }
        
        let powerView = PowerDisplayView()
        powerView.backgroundColor = .clear
        view.addSubview(powerView)
        powerView.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(Appearance.displayRect.minX)
            make.bottom.equalToSuperview().offset(-bottomMargin)
            make.size.equalTo(CGSize(width: 25, height: 12))
        }
        
        
        timeLabel.text = PageReaderDisplayCell.dateFormatter.string(from: Date())
        view.addSubview(timeLabel)
        timeLabel.snp.makeConstraints { (make) in
            make.left.equalTo(powerView.snp.right).offset(5)
            make.centerY.equalTo(powerView)
        }
        
        progressLabel.text = String(format: "%.1f%%", pageItem.progress * 100)
        view.addSubview(progressLabel)
        progressLabel.snp.makeConstraints { (make) in
            make.right.equalToSuperview().offset(-Appearance.displayRect.minX)
            make.bottom.equalToSuperview().offset(-bottomMargin)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                (view as! TextDisplayView).attributedString = NSAttributedString(string: pageItem.content, attributes: Appearance.attributes)
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.view.layer.setNeedsDisplay()
    }
    
}

// MARK: - TextDisplayView

private final class TextDisplayView: UIView {
    
    private lazy var textLabel = UILabel()
    
    var attributedString: NSAttributedString? {
        get { textLabel.attributedText }
        set { textLabel.attributedText = newValue }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        textLabel.numberOfLines = 0
        addSubview(textLabel)
        textLabel.snp.makeConstraints { make in
            let horizenPadding = Appearance.displayRect.origin.x
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: horizenPadding, bottom: 0, right: horizenPadding))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

// MARK: - PowerDisplayView

private final class PowerDisplayView: UIView {
    
    var batteryLevel: Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        if UIDevice.current.batteryState == .unknown { return 0 }
        let value = UIDevice.current.batteryLevel
        UIDevice.current.isBatteryMonitoringEnabled = false
        return value
    }
    
    private lazy var outline: CAShapeLayer = {
        let shape = CAShapeLayer()
        shape.contentsScale = UIScreen.main.scale
        if #available(iOS 13, *) {
            shape.strokeColor = Appearance.readerOtherColor.resolvedColor(with: traitCollection).cgColor
        } else {
            shape.strokeColor = Appearance.readerOtherColor.cgColor
        }
        shape.fillColor = UIColor.clear.cgColor
        shape.lineWidth = 1
        return shape
    }()
        
    private lazy var cap: CAShapeLayer = {
        let shape = CAShapeLayer()
        shape.contentsScale = UIScreen.main.scale
        shape.strokeColor = UIColor.clear.cgColor
        if #available(iOS 13, *) {
            shape.fillColor = Appearance.readerOtherColor.resolvedColor(with: traitCollection).cgColor
        } else {
            shape.fillColor = Appearance.readerOtherColor.cgColor
        }
        return shape
    }()
    
    private lazy var inner: CAShapeLayer = {
        let shape = CAShapeLayer()
        shape.contentsScale = UIScreen.main.scale
        shape.strokeColor = UIColor.clear.cgColor
        if #available(iOS 13, *) {
            shape.fillColor = Appearance.readerOtherColor.resolvedColor(with: traitCollection).cgColor
        } else {
            shape.fillColor = Appearance.readerOtherColor.cgColor
        }
        return shape
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                let color = Appearance.readerOtherColor.resolvedColor(with: traitCollection).cgColor
                outline.strokeColor = color
                cap.fillColor = color
                inner.fillColor = color
            }
        }
    }
    
    private func setupUI() {
        layer.addSublayer(outline)
        layer.addSublayer(cap)
        layer.addSublayer(inner)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let width = frame.width
        let height = frame.height
        let padding: CGFloat = 2
        let radius: CGFloat = 2
        let capRadius: CGFloat = height / 6
        
        let outlineWidth = width - capRadius - padding
        let outlineHeight = height - 2
        let outlinePath = UIBezierPath(roundedRect: CGRect(x: 1, y: 1, width: outlineWidth, height: height - 2), cornerRadius: radius)
        outline.path = outlinePath.cgPath
        
        
        let capPath = UIBezierPath(arcCenter: CGPoint(x: outlineWidth + 1 + padding, y: height / 2), radius: capRadius, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
        cap.path = capPath.cgPath

        let innerPath = UIBezierPath(roundedRect: CGRect(x: 1 + padding, y: 1 + padding, width: (outlineWidth - padding * 2) * CGFloat(batteryLevel), height: outlineHeight - padding * 2), cornerRadius: 1)
        inner.path = innerPath.cgPath
    }
}
