import Foundation
import Combine

@MainActor
final class AudioListViewModel {
    @Published
    private(set) var dataList: [AudioModel] = (0...3).map({ _ in AudioModel(name: "22222222") })
    
    @discardableResult
    func removeItem(at index: Int) -> AudioModel? {
        guard index < dataList.count else { return nil }
        return dataList.remove(at: index)
    }
}
