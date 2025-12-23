import Foundation
import Combine

@MainActor
final class AudioListViewModel {
    @Published
    private(set) var dataList: [AudioModel] = []
    
    func loadAudioList() async throws {
        let res = try await loadData()
        dataList = res
    }
    
    func updateAccessDate(_ accessDate: TimeInterval, forAudio audio: String) {
        Task.detached(priority: .background) {
            do {
                try Database.shared.updateAccessDate(accessDate, forAudio: audio)
            } catch {
                print("update accessDate failure: \(error.localizedDescription)")
            }
        }
    }
    
    func removeItem(at index: Int) {
        guard index < dataList.count else { return }
        let item = dataList.remove(at: index)
        do {
            try Database.shared.removeAudio(item.name)
            try FileManager.default.removeItem(at: item.localPath)
        } catch {
            print("remove failure: \(error.localizedDescription)")
        }
    }
    
    func progress(forAudio audio: String) -> TimeInterval? {
        try? Database.shared.progress(forAudio: audio)
    }
    
    func updateProgress(_ progress: TimeInterval, forAudio audio: String) {
        
        Task.detached(priority: .background) {
            do {
                try Database.shared.updateProgress(progress, forAudio: audio)
            } catch {
                print("update accessDate failure: \(error.localizedDescription)")
            }
        }
    }
    
}

// MARK: - database concurrency
extension AudioListViewModel {
    @concurrent
    nonisolated
    private func loadData() async throws -> [AudioModel] {
        try Database.shared.loadAudioList()
    }
}
