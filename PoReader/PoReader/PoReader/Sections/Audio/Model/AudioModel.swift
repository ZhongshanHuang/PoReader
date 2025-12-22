import Foundation

struct AudioModel: Identifiable, Hashable {
    let id = UUID()
    let name: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: AudioModel, rhs: AudioModel) -> Bool {
        return lhs.id == rhs.id
    }
}
