import UIKit

open class TransitionInteractiveController: UIPercentDrivenInteractiveTransition {

    // MARK: - Private
    private(set) var gestureRecognizer: UIPanGestureRecognizer?
    private var shouldCompleteTransition = false
    private(set) var interactionInProgress = false
    
    private enum InteractionConstants {
        static let velocityForComplete: CGFloat = 100.0
        static let velocityForCancel: CGFloat = -5.0
    }
    
    // MARK: - Public
    
    open var isEnabled = true {
        didSet { gestureRecognizer?.isEnabled = isEnabled }
    }
    open var completeOnPercentage: CGFloat = 0.5
    open var navigationAction: (() -> Void) = {
        fatalError("Missing navigationAction (ex: navigation.dismiss) on TransitionInteractiveController")
    }
    open var shouldBeginTransition: () -> Bool = { return true }
    open weak var gestureRecognizerDelegate: (any UIGestureRecognizerDelegate)?
    
    deinit {
        if let gestureRecognizer = gestureRecognizer {
            gestureRecognizer.view?.removeGestureRecognizer(gestureRecognizer)
        }
    }
    
    /// Sets the viewController to be the one in charge of handling the swipe transition.
    ///
    /// - Parameter viewController: `UIViewController` in charge of the the transition.
    open func addPanGesture(to view: UIView, with panType: PanGestureType, delegate: (any UIGestureRecognizerDelegate)? = nil) {
        if let gestureRecognizer = gestureRecognizer {
            gestureRecognizer.view?.removeGestureRecognizer(gestureRecognizer)
        }
        self.gestureRecognizerDelegate = delegate
        gestureRecognizer = TransitionPanGestureFactory.create(with: panType)
        gestureRecognizer?.addTarget(self, action: #selector(handle(_:)))
        gestureRecognizer?.delegate = self
        gestureRecognizer?.isEnabled = isEnabled
        view.addGestureRecognizer(gestureRecognizer!)
    }
    
    /// Handles the swiping with progress
    ///
    /// - Parameter recognizer: `UIPanGestureRecognizer` in the current tab controller's view.
    @objc
    open func handle(_ recognizer: UIGestureRecognizer) {
        guard let panGesture = recognizer as? TransitionPanGestureProtocol else { return }
        let panVelocity = panGesture.completionSpeed()
        let panned = panGesture.percentComplete()
        switch recognizer.state {
        case .began:
            if panVelocity > 0 {
                interactionInProgress = true
                navigationAction()
            }
        case .changed:
            if interactionInProgress {
                let fraction = min(max(panned, 0.0), 0.99)
                update(fraction)
            }
        case .ended, .cancelled:
            if interactionInProgress {
                interactionInProgress = false
                shouldCompleteTransition = (panned > completeOnPercentage || panVelocity > InteractionConstants.velocityForComplete) &&
                    panVelocity > InteractionConstants.velocityForCancel
                shouldCompleteTransition ? finish() : cancel()
            }
        default:
            break
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension TransitionInteractiveController: UIGestureRecognizerDelegate {
    
//    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        if let scrollView = otherGestureRecognizer.view as? UIScrollView {
//            return scrollView.contentOffset.y <= 0
//        }
//        return true
//    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if !shouldBeginTransition() {
            return false
        }
        return gestureRecognizerDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizerDelegate?.gestureRecognizer?(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) ?? false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizerDelegate?.gestureRecognizer?(gestureRecognizer, shouldRequireFailureOf: otherGestureRecognizer) ?? false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizerDelegate?.gestureRecognizer?(gestureRecognizer, shouldBeRequiredToFailBy: otherGestureRecognizer) ?? false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        gestureRecognizerDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: touch) ?? true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        gestureRecognizerDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: press) ?? true
    }

    @available(iOS 13.4, *)
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        gestureRecognizerDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: event) ?? true
    }
    
}
