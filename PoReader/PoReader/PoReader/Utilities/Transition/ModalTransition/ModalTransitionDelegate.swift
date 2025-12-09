import UIKit

public class ModalTransitionDelegate: NSObject {
    public enum ModalOperation {
        case present
        case dismiss
    }
    
    private var animationConfigs = [ModalOperation: any ModalTransitionAnimationConfigurable]()
    private let interactiveController = TransitionInteractiveController()
    public var interactiveGestureRecognizer: UIGestureRecognizer? { interactiveController.gestureRecognizer }
    public var presentationController: UIPresentationController?
    
    public func addPanGesture(to view: UIView, with panType: PanGestureType, delegate: (any UIGestureRecognizerDelegate)? = nil, navigationAction: @escaping () -> Void, beginWhen: @escaping (() -> Bool) = { true }) {
        interactiveController.addPanGesture(to: view, with: panType, delegate: delegate)
        interactiveController.navigationAction = navigationAction
        interactiveController.shouldBeginTransition = beginWhen
    }
    
    public func set(animatorConfig: any ModalTransitionAnimationConfigurable, for operation: ModalOperation) {
        animationConfigs[operation] = animatorConfig
    }

    public func removeAnimatorConfig(for operation: ModalOperation) {
        animationConfigs[operation] = nil
    }
}

// MARK: - UIViewControllerTransitioningDelegate
extension ModalTransitionDelegate: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        guard let config = animationConfigs[.present] else { return nil }
        return ModalTransitionAnimator(config: config)
    }

    public func animationController(forDismissed dismissed: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        guard let config = animationConfigs[.dismiss] else { return nil }
        return ModalTransitionAnimator(config: config)
    }

    public func interactionControllerForPresentation(using animator: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
        interactiveController.interactionInProgress ? interactiveController : nil
    }

    public func interactionControllerForDismissal(using animator: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
        interactiveController.interactionInProgress ? interactiveController : nil
    }

    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        presentationController
    }
}
