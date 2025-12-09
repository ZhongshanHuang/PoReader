import UIKit

public enum PanDirection {
    case fromTop
    case fromLeft
    case fromBottom
    case fromRight
}

public enum PanGestureType {
    case regular(PanDirection)
    case edge(UIRectEdge)
}

protocol TransitionPanGestureProtocol: AnyObject {
    var type: PanGestureType { get }
    init(type: PanGestureType)
    func percentComplete() -> CGFloat
    func completionSpeed() -> CGFloat
}

extension TransitionPanGestureProtocol where Self: UIPanGestureRecognizer {
    func percentComplete() -> CGFloat {
        guard let view = view else { return 0 }
        
        let translation = self.translation(in: view)
        switch type {
        case .regular(let direction):
            switch direction {
            case .fromTop:
                return translation.y / view.bounds.height
            case .fromLeft:
                return translation.x / view.bounds.width
            case .fromBottom:
                return -translation.y / view.bounds.height
            case .fromRight:
                return -translation.x / view.bounds.width
            }
        case .edge(let rectEdge):
            switch rectEdge {
            case .top:
                return translation.y / view.bounds.height
            case .left:
                return translation.x / view.bounds.width
            case .bottom:
                return -translation.y / view.bounds.height
            case .right:
                return -translation.x / view.bounds.width
            default:
                return 0
            }
        }
    }
    
    func completionSpeed() -> CGFloat {
        guard let view = view else { return 0 }
        
        let velocity = self.velocity(in: view)
        switch type {
        case .regular(let direction):
            switch direction {
            case .fromTop:
                return velocity.y
            case .fromLeft:
                return velocity.x
            case .fromBottom:
                return -velocity.y
            case .fromRight:
                return -velocity.x
            }
        case .edge(let rectEdge):
            switch rectEdge {
            case .top:
                return velocity.y
            case .left:
                return velocity.x
            case .bottom:
                return -velocity.y
            case .right:
                return -velocity.x
            default:
                return 0
            }
        }
    }
}

class TransitionPanGestureRecognizer: UIPanGestureRecognizer, TransitionPanGestureProtocol {
    let type: PanGestureType
    
    required init(type: PanGestureType) {
        self.type = type
        super.init(target: nil, action: nil)
    }
}

class TransitionEdgePanGestureRecognizer: UIScreenEdgePanGestureRecognizer, TransitionPanGestureProtocol {
    let type: PanGestureType
    
    required init(type: PanGestureType) {
        self.type = type
        super.init(target: nil, action: nil)
    }
}

struct TransitionPanGestureFactory {
    
    static func create(with panType: PanGestureType) -> UIPanGestureRecognizer {
        let gestureRecognizer: UIPanGestureRecognizer
        switch panType {
        case .regular:
            gestureRecognizer = TransitionPanGestureRecognizer(type: panType)
        case .edge(let uIRectEdge):
            let edgeGestureRecognizer = TransitionEdgePanGestureRecognizer(type: panType)
            edgeGestureRecognizer.edges = uIRectEdge
            gestureRecognizer = edgeGestureRecognizer
        }
        return gestureRecognizer
    }
    
}
