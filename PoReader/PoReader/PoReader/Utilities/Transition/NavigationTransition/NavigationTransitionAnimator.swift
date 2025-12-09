import UIKit

public typealias AuxAnimation = (closure: () -> Void, relativeDelay: Double)

public protocol NavigationTransitionAnimationConfigurable {
    var duration: TimeInterval { get }
    var auxAnimations: ((Bool) -> [AuxAnimation])? { get }
    var onCompletion: ((Bool) -> Void)? { get }
    
    func layout(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView)
    func animations(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView)
}

public extension NavigationTransitionAnimationConfigurable {
    var duration: TimeInterval { 0.25 }
    var auxAnimations: ((Bool) -> [AuxAnimation])? { nil }
    var onCompletion: ((Bool) -> Void)? { nil }
    
    func layout(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {
        if presenting {
            toView.transform = .identity.translatedBy(x: toView.bounds.width, y: 0)
        }
    }
    
    func animations(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {
        if presenting {
            toView.transform = .identity
        } else {
            fromView.transform = .identity.translatedBy(x: fromView.bounds.width, y: 0)
        }
    }
}

final class NavigationTransitionAnimator: NSObject {
    private let config: NavigationTransitionAnimationConfigurable
    private var animator: UIViewPropertyAnimator?
    
    public init(config: NavigationTransitionAnimationConfigurable) {
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
        
        
        
        config.layout(presenting: isPush, fromView: fromView,
                                  toView: toView, in: containerView)
        
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, curve: .linear)
        animator.addAnimations {
            UIView.animateKeyframes(withDuration: duration, delay: 0.0, options: [], animations: {
                
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1, animations: {
                    self.config.animations(presenting: isPush,fromView: fromView,
                                                       toView: toView, in: containerView)
                })
                
                if let auxAnimations = self.config.auxAnimations?(isPush) {
                    for animation in auxAnimations {
                        let relativeDuration = duration - animation.relativeDelay * duration
                        UIView.addKeyframe(withRelativeStartTime: animation.relativeDelay,
                                           relativeDuration: relativeDuration,
                                           animations: animation.closure)
                    }
                }
            }) { _ in
            }
        }
        animator.addCompletion { position in
            switch position {
            case .end:
              transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                self.config.onCompletion?(isPush)
            default:
              transitionContext.completeTransition(false)
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
