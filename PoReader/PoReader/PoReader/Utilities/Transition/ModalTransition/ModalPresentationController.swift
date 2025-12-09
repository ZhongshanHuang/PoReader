import UIKit

class ModalPresentationController: UIPresentationController {
    
    var percentHeight: CGFloat = 0.8
    var needDimming: Bool = true
    var dimmingColor: UIColor = UIColor(white: 0, alpha: 0.5)
    var allowsTapToDismiss: Bool = true
    var presentedViewFrame: ((_ container: UIView) -> CGRect)?
    
    private var dimmingView: UIView?
    
    override var frameOfPresentedViewInContainerView: CGRect {
        let bounds = containerView?.bounds ?? .zero
        return CGRect(x: 0, y: bounds.height * (1 - percentHeight), width: bounds.width, height: bounds.height * percentHeight)
    }
    
    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        guard let containerView else { return }
        if needDimming {
            let dimming = UIView()
            dimming.backgroundColor = dimmingColor
            dimming.alpha = 0
            
            containerView.addSubview(dimming)
            dimming.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dimming.topAnchor.constraint(equalTo: containerView.topAnchor),
                dimming.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                dimming.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                dimming.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            
            if allowsTapToDismiss {
                dimming.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:))))
            }
            
            presentedViewController.transitionCoordinator?.animate { _ in
                dimming.alpha = 1
            } completion: { _ in
            }
            
            dimmingView = dimming
        }
    }
    
    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        if needDimming {
            presentedViewController.transitionCoordinator?.animate { _ in
                self.dimmingView?.alpha = 0
            } completion: { _ in
            }
        }
    }
    
    // MARK: - Selectors
    @objc
    private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard let presentedView else { return }
        
        let location = gesture.location(in: dimmingView!)
        if !presentedView.frame.contains(location) {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
    }
}
