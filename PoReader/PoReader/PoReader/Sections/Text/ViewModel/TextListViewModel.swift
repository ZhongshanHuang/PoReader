import Foundation
import Combine

@MainActor
final class TextListViewModel {
    @Published
    private(set) var dataList: [BookModel] = []
    
    func loadBookList() async throws {
        let res = try await loadData()
        dataList = res
    }
    
    func remove(_ books: Set<BookModel>) {
        dataList.removeAll(where: { (book) -> Bool in
            books.contains(book)
        })
        books.forEach { book in
            do {
                try Database.shared.removeBook(book.name)
                try FileManager.default.removeItem(at: book.localPath)
            } catch {
                print("remove failure: \(error.localizedDescription)")
            }
        }
    }
    
    func update(_ accessDate: TimeInterval, at index: Int) {
        guard index < dataList.count else { return }
        dataList[index].lastAccessDate = accessDate
        
        let name = dataList[index].name
        Task.detached(priority: .background) {
            do {
                try Database.shared.update(accessDate, forBook: name)
            } catch {
                print("update accessDate failure: \(error.localizedDescription)")
            }
        }
    }
    
}

// MARK: - database concurrency
extension TextListViewModel {
    @concurrent
    nonisolated
    private func loadData() async throws -> [BookModel] {
        try Database.shared.loadBookList()
    }
}
