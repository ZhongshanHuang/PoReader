import UIKit

final class NavigationTransitionAnimator: NSObject {
    private let config: TransitionAnimationConfigurable
    private var animator: UIViewPropertyAnimator?
    
    public init(config: TransitionAnimationConfigurable) {
        self.config = config
    }
}

// MARK: - UIViewControllerAnimatedTransitioning
extension NavigationTransitionAnimator: UIViewControllerAnimatedTransitioning {
    
    public func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        config.duration
    }
    
    public func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        transitionAnimator(using: transitionContext).startAnimation()
    }
    
    public func interruptibleAnimator(using transitionContext: any UIViewControllerContextTransitioning) -> any UIViewImplicitlyAnimating {
        animator ?? transitionAnimator(using: transitionContext)
    }
    
    private func transitionAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        guard let fromViewController = transitionContext.viewController(forKey: .from),
            let toViewController = transitionContext.viewController(forKey: .to) else {
            return UIViewPropertyAnimator()
        }
        
        let containerView = transitionContext.containerView
        let fromView = fromViewController.view!
        let toView = toViewController.view!

        var isPush = false
        if let toIndex = toViewController.navigationController?.viewControllers.firstIndex(of: toViewController),
            let fromIndex = fromViewController.navigationController?.viewControllers.firstIndex(of: fromViewController) {
            isPush = toIndex > fromIndex
        }
        
        if isPush {
            toView.transform = .identity
            containerView.addSubview(toView)
        } else {
            containerView.insertSubview(toView, belowSubview: fromView)
        }
        
        let fromFrame = transitionContext.initialFrame(for: fromViewController)
        let toFrame = transitionContext.finalFrame(for: toViewController)
        
        fromView.frame = fromFrame
        toView.frame = toFrame
        
        config.layout(presenting: isPush, fromView: fromView, toView: toView, in: containerView)
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, curve: .linear)
        animator.addAnimations {
            UIView.animateKeyframes(withDuration: duration, delay: 0.0, options: [], animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1, animations: {
                    self.config.animate(presenting: isPush,fromView: fromView, toView: toView, in: containerView)
                })
                
                let auxAnimations = self.config.auxAnimations(presenting: isPush, fromView: fromView, toView: toView, in: containerView)
                for animation in auxAnimations {
                    UIView.addKeyframe(withRelativeStartTime: animation.relativeStartTime,
                                       relativeDuration: animation.relativeDuration,
                                       animations: animation.closure)
                }
            }) { _ in
            }
        }
        animator.addCompletion { position in
            switch position {
            case .end:
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                self.config.completeTransition(didComplete: !transitionContext.transitionWasCancelled, presenting: isPush, fromView: fromView, toView: toView, in: containerView)
            default:
                transitionContext.completeTransition(false)
                self.config.completeTransition(didComplete: false, presenting: isPush, fromView: fromView, toView: toView, in: containerView)
            }
        }
        self.animator = animator
        animator.addCompletion { _ in
            self.animator = nil
        }
        animator.isUserInteractionEnabled = true
        return animator
    }
    
}
