import UIKit

@MainActor
protocol PoAsyncLayerDelegate: CALayerDelegate {
    func asyncLayerPrepare(_ layer: CALayer) -> PoTextRenderRequest
    func asyncLayerWillDisplay(_ layer: CALayer, request: PoTextRenderRequest)
    func asyncLayerDidDisplay(_ layer: CALayer, request: PoTextRenderRequest, result: PoTextRenderResult)
}

/// CALayer's nonisolated entry points bridge into MainActor. All mutable layer
/// state stays there; only immutable requests/results pass to the render worker.
@MainActor
final class PoAsyncLayer: CALayer, @unchecked Sendable {
    var isDisplayedAsynchronously = true
    private lazy var renderer = PoTextRenderer()
    private var asyncTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    private struct MainActorReference: Sendable {
        let layer: PoAsyncLayer
    }

    nonisolated override class func defaultAction(forKey event: String) -> (any CAAction)? { nil }

    nonisolated override func setNeedsDisplay() {
        let reference = MainActorReference(layer: self)
        MainActor.assumeIsolated { reference.layer.cancelDisplay() }
        super.setNeedsDisplay()
    }

    nonisolated override func setNeedsDisplay(_ r: CGRect) {
        let reference = MainActorReference(layer: self)
        MainActor.assumeIsolated { reference.layer.cancelDisplay() }
        super.setNeedsDisplay(r)
    }

    nonisolated override func setNeedsLayout() {
        let reference = MainActorReference(layer: self)
        MainActor.assumeIsolated { reference.layer.cancelDisplay() }
        super.setNeedsLayout()
    }

    nonisolated override func display() {
        let reference = MainActorReference(layer: self)
        MainActor.assumeIsolated { reference.layer.displayOnMainActor() }
    }

    private func displayOnMainActor() {
        cancelDisplay()
        guard let delegate = delegate as? any PoAsyncLayerDelegate else { return }
        let delegateID = ObjectIdentifier(delegate)
        let request = delegate.asyncLayerPrepare(self)
        delegate.asyncLayerWillDisplay(self, request: request)
        let currentGeneration = generation

        // Empty/zero-size display clears synchronously, without a worker hop.
        if request.size.width < 1 || request.size.height < 1 || request.isEmpty {
            commit(PoTextRenderResult(image: nil, layout: nil, drawingPoint: .zero), request: request)
        } else if isDisplayedAsynchronously {
            let worker = renderer
            asyncTask = Task(priority: .userInitiated) { [weak self, worker, request] in
                do {
                    try Task.checkCancellation()
                    let result = try await worker.render(request)
                    try Task.checkCancellation()
                    guard let self, self.generation == currentGeneration,
                          self.delegate.map(ObjectIdentifier.init) == delegateID else { return }
                    self.asyncTask = nil
                    self.commit(result, request: request)
                } catch is CancellationError {
                    // A cancelled request owns no UI objects and has nothing to
                    // undo. Its result must never touch a newer display.
                } catch {
                    assertionFailure("Unexpected text rendering failure: \(error)")
                }
            }
        } else if let result = try? PoTextRenderer.renderImmediately(request) {
            commit(result, request: request)
        }
    }

    private func commit(_ result: PoTextRenderResult, request: PoTextRenderRequest) {
        contents = result.image?.cgImage
        (delegate as? any PoAsyncLayerDelegate)?.asyncLayerDidDisplay(self, request: request, result: result)
    }

    private func cancelDisplay() {
        generation &+= 1
        asyncTask?.cancel()
        asyncTask = nil
    }
}

private extension PoTextRenderRequest {
    var isEmpty: Bool {
        if case .empty = source { return true }
        return false
    }
}
