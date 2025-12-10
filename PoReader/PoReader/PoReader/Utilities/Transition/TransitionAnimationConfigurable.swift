import UIKit

public typealias AuxAnimation = (closure: () -> Void, relativeStartTime: TimeInterval, relativeDuration: TimeInterval)

public protocol TransitionAnimationConfigurable {
    var duration: TimeInterval { get }
    
    func layout(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView)
    func animate(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView)
    func auxAnimations(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) -> [AuxAnimation]
    func completeTransition(didComplete: Bool, presenting: Bool, fromView: UIView, toView: UIView, in container: UIView)
}

extension TransitionAnimationConfigurable {
    var duration: TimeInterval { 0.35 }
    
    func auxAnimations(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) -> [AuxAnimation] { [] }
    func completeTransition(didComplete: Bool, presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {}
}
