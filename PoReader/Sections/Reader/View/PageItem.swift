//
//  PageItem.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/18.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

class PageItem: UIViewController {

    /// 章节索引
    var chapterIndex: Int = -1
    /// 章节内部分页索引
    var subrangeIndex: Int = -1
    /// 显示内容
    var content: String?
    /// 进度
    var progress: Float = 0
    /// 书名或者章节名
    var header: String?
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = Appearance.readerOtherColor
        return label
    }()
    
    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10)
        label.textColor = Appearance.readerOtherColor
        return label
    }()
    
    override func loadView() {
        view = TextDisplayView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = Appearance.readerBackgroundColor
        (view as! TextDisplayView).attributedString = NSAttributedString(string: content ?? "", attributes: Appearance.attributes)
        
        titleLabel.text = header
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            let margin = Appearance.displayRect.minX
            let topMargin: CGFloat
            if UIDevice.isNotch {
                topMargin = 40
            } else {
                topMargin = 10
            }
            make.top.equalToSuperview().offset(topMargin)
            make.left.equalToSuperview().offset(margin)
            make.right.equalToSuperview().offset(-margin)
        }
        
        let powerView = PowerDisplayView()
        powerView.backgroundColor = .clear
        view.addSubview(powerView)
        powerView.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(Appearance.displayRect.minX)
            make.bottom.equalToSuperview().offset(-Appearance.displayRect.minY + 8)
            make.size.equalTo(CGSize(width: 25, height: 12))
        }
        
        progressLabel.text = String(format: "%.1f%%", progress * 100)
        view.addSubview(progressLabel)
        progressLabel.snp.makeConstraints { (make) in
            make.right.equalToSuperview().offset(-Appearance.displayRect.minX)
            make.bottom.equalToSuperview().offset(-Appearance.displayRect.minY + 8)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                (view as! TextDisplayView).attributedString = NSAttributedString(string: content ?? "", attributes: Appearance.attributes)
            }
        }
    }
    
}

// MARK: - TextDisplayView

private final class TextDisplayView: UIView {
    
    var attributedString: NSAttributedString? {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    
    override class var layerClass: AnyClass {
        return PoAsyncLayer.self
    }
}

// MARK: - PoAsyncLayerDelegate

extension TextDisplayView: PoAsyncLayerDelegate {
    
    /// 将文本的宽高计算、渲染移到后台线程
    func newAsyncDisplayTask() -> PoAsyncLayerDisplayTask {
        let displayTask = PoAsyncLayerDisplayTask()
        displayTask.display = { (context, size, isCancelled) in
            context.textMatrix = .identity
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
            
            let frameSetter = CTFramesetterCreateWithAttributedString(self.attributedString ?? NSAttributedString())
            // 这儿的坐标系原点在左下方
            let path = CGPath(rect: Appearance.displayRect, transform: nil)
            let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, nil)
            CTFrameDraw(frame, context)
        }
        return displayTask
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
