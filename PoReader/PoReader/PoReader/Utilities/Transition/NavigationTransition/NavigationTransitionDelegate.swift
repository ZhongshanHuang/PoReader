import UIKit

public class NavigationTransitionDelegate: NSObject {
    private var animationConfigs = [UINavigationController.Operation: any TransitionAnimationConfigurable]()
    private let interactiveController = TransitionInteractiveController()
    public var interactiveGestureRecognizer: UIGestureRecognizer? { interactiveController.gestureRecognizer }
    
    public func addPanGesture(to viewController: UIViewController, with panType: PanGestureType, delegate: (any UIGestureRecognizerDelegate)? = nil, navigationAction: @escaping () -> Void, beginWhen: @escaping (() -> Bool) = { true }) {
        interactiveController.addPanGesture(to: viewController.view, with: panType, delegate: delegate)
        interactiveController.navigationAction = navigationAction
        interactiveController.shouldBeginTransition = beginWhen
    }
    
    public func set(animatorConfig: any TransitionAnimationConfigurable, for operation: UINavigationController.Operation) {
        animationConfigs[operation] = animatorConfig
    }

    public func removeAnimatorConfig(for operation: UINavigationController.Operation) {
        animationConfigs[operation] = nil
    }
    
}

// MARK: - UINavigationControllerDelegate
extension NavigationTransitionDelegate: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let config = animationConfigs[operation] else { return nil }
        return NavigationTransitionAnimator(config: config)
    }
    
    public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        interactiveController.interactionInProgress ? interactiveController : nil
    }
}
