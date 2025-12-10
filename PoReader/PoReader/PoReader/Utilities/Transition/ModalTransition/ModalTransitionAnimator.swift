import UIKit

public protocol ModalTransitionAnimationConfigurable {
    var duration: TimeInterval { get }
    var auxAnimation: ((Bool) -> Void)? { get }
    var onCompletion: ((Bool) -> Void)? { get }
    func layout(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView)
    func animate(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView)
}

public extension ModalTransitionAnimationConfigurable {
    var duration: TimeInterval { 0.35 }
    var auxAnimation: ((Bool) -> Void)? { nil }
    var onCompletion: ((Bool) -> Void)? { nil }
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
}

final class ModalTransitionAnimator: NSObject {
    private let config: any ModalTransitionAnimationConfigurable
    private var animator: UIViewPropertyAnimator?
    
    init(config: any ModalTransitionAnimationConfigurable) {
        self.config = config
    }
}

// MARK: - UIViewControllerAnimatedTransitioning
extension ModalTransitionAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return config.duration
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
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
        let fromView: UIView = fromViewController.view
        let toView: UIView = toViewController.view
        
        let isPresenting = toViewController.presentingViewController === fromViewController
        if isPresenting {
            let proposedFrame = transitionContext.finalFrame(for: toViewController)
            toView.transform = .identity
            toView.frame = proposedFrame
            containerView.addSubview(toView)
        } else {
            if fromViewController.modalPresentationStyle == .fullScreen {
                containerView.insertSubview(toView, belowSubview: fromView)
            }
        }
        
        config.layout(presenting: isPresenting, fromView: fromView, toView: toView, in: containerView)
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, curve: .linear)
        animator.addAnimations {
            self.config.animate(presenting: isPresenting, fromView: fromView, toView: toView, in: containerView)
        }
        animator.addCompletion { position in
            switch position {
            case .end:
              transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                self.config.onCompletion?(isPresenting)
            default:
              transitionContext.completeTransition(false)
            }
        }
        if let auxAnimation = config.auxAnimation {
            animator.addAnimations({ auxAnimation(isPresenting) })
        }
        self.animator = animator
        animator.addCompletion { _ in
            self.animator = nil
        }
        animator.isUserInteractionEnabled = true
        return animator
    }
    
}
