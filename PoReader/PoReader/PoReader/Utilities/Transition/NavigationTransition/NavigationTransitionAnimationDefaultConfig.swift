import UIKit

class NavigationTransitionAnimationDefaultConfig: TransitionAnimationConfigurable {
    var duration: TimeInterval { 0.35 }
    
    func layout(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {
        if presenting {
            toView.transform = .identity.translatedBy(x: toView.bounds.width, y: 0)
        }
    }
    
    func animate(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {
        if presenting {
            toView.transform = .identity
        } else {
            fromView.transform = .identity.translatedBy(x: fromView.bounds.width, y: 0)
        }
    }
    
    func auxAnimations(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) -> [AuxAnimation] { [] }
    
    func completeTransition(didComplete: Bool, presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {}
}
