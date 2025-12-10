import UIKit

class ModalTransitionAnimationDefaultConfig: TransitionAnimationConfigurable {
    var duration: TimeInterval { 0.35 }
    
    func layout(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {
        if presenting {
            toView.transform = .identity.translatedBy(x: 0, y: toView.bounds.height)
        }
    }
    
    func animate(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {
        if presenting {
            toView.transform = .identity
        } else {
            fromView.transform = .identity.translatedBy(x: 0, y: fromView.bounds.height)
        }
    }
    
    func auxAnimations(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) -> [AuxAnimation] { [] }
    
    func completeTransition(didComplete: Bool, presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {}
}
