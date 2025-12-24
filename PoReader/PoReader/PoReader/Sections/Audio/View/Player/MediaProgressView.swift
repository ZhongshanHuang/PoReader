import UIKit

class MediaProgressView: UIControl {
    
    private var _progressValue: Float = 0
    var progressValue: Float {
        get { return _progressValue }
        set {
            if newValue.isNaN { return }
            if abs(newValue - _progressValue) < 0.01 { return }
            if newValue < 0 {
                if _progressValue == 0 { return }
                _progressValue = 0
            } else if newValue > 1 {
                if _progressValue == 1 { return }
                _progressValue = 1
            } else {
                _progressValue = newValue
            }
            setNeedsDisplay()
        }
    }

    private var _sliderValue: Float = 0
    var sliderValue: Float {
        get { return _sliderValue }
        set {
            if newValue.isNaN { return }
            if abs(newValue - _sliderValue) < 0.01 { return }
            if newValue < 0 {
                _sliderValue = 0
            } else if newValue > 1 {
                _sliderValue = 1
            } else {
                _sliderValue = newValue
            }
            setNeedsDisplay()
        }
    }
    
    var backgroundTintColor: UIColor = UIColor.darkGray {
        didSet { setNeedsDisplay() }
    }
    var progressTintColor: UIColor = UIColor.systemGray4 {
        didSet { setNeedsDisplay() }
    }
    var sliderTintColor: UIColor = UIColor.white {
        didSet { setNeedsDisplay() }
    }
    var thumbTintColor: UIColor = UIColor.white {
        didSet { setNeedsDisplay() }
    }
    private var _thumbRect: CGRect = .zero
    private var _thumbRadius: CGFloat = 4
    
    var isContinuous: Bool = true
    private(set) var isTouching: Bool = false
    private var isTrack: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    private func setUp() {
        backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let lineWidth: CGFloat = isTrack ? 3 : 1
        let width = bounds.width - _thumbRadius * 2
        let centerY = bounds.height / 2
        
        let value = CGFloat(1 - max(progressValue, sliderValue)) * width
        if value >= 1 {
            context.saveGState()
            defer { context.restoreGState() }
            
            let startPoint = CGPoint(x: CGFloat(max(progressValue, sliderValue)) * width + _thumbRadius, y: centerY)
            let endPoint = CGPoint(x: width + _thumbRadius, y: centerY)
            context.setStrokeColor(backgroundTintColor.cgColor)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.strokePath()
        }
        
        if sliderValue < progressValue {
            context.saveGState()
            defer { context.restoreGState() }
            
            let startPoint = CGPoint(x: CGFloat(sliderValue) * width + _thumbRadius, y: centerY)
            let endPoint = CGPoint(x: CGFloat(progressValue) * width + _thumbRadius, y: centerY)
            context.setStrokeColor(progressTintColor.cgColor)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.strokePath()
        }
        
        if sliderValue > 0 {
            context.saveGState()
            defer { context.restoreGState() }
            
            let startPoint = CGPoint(x: _thumbRadius, y: centerY)
            let endPoint = CGPoint(x: CGFloat(sliderValue) * width + _thumbRadius, y: centerY)
            context.setStrokeColor(sliderTintColor.cgColor)
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.strokePath()
        }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        let sliderX = CGFloat(sliderValue) * width
        let radius = isTrack ? _thumbRadius * 1.5 : _thumbRadius
        _thumbRect = CGRect(x: sliderX, y: centerY - radius, width: radius * 2, height: radius * 2)
        context.addEllipse(in: _thumbRect)
        context.setFillColor(thumbTintColor.cgColor)
        context.fillPath()
        context.setStrokeColor(UIColor.gray.cgColor)
        context.setLineWidth(1)
        context.strokePath()
    }
}

extension MediaProgressView {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = touches.count == 1
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTouching {
            isTrack = true
            let point = touches.first!.location(in: self)
            let value = point.x - _thumbRadius
            let newValue = Float(value / (bounds.width - _thumbRadius * 2))
            if newValue < -0.01 || newValue > 1.01 { return }
            if abs(newValue - _sliderValue) < 0.01 { return }
            sliderValue = newValue
            if isContinuous {
                sendActions(for: .valueChanged)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTouching {
            let point = touches.first!.location(in: self)
            let value = point.x
            let newValue = Float(value / (bounds.width - _thumbRadius * 2))
            sliderValue = newValue
            sendActions(for: .valueChanged)
            setNeedsDisplay()
        }
        isTouching = false
        isTrack = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isTouching {
            setNeedsDisplay()
        }
        isTouching = false
        isTrack = false
    }
}
