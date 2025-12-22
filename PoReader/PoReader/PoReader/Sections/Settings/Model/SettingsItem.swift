import Foundation

// MARK: - Data

extension SettingsItem {
    static let allCasesWidgets: [SettingsCellProtocol.Type] = [SettingsSwitchCell.self, SettingsSelectCell.self]
}

struct SettingsItem: Hashable {
    
    enum ItemType: String {
        case appearanceMode = "观看模式"
        case autoOpenBook = "自动打开最近浏览书籍"
        case transitionStyle = "翻页风格"
    }
    
    enum DataType {
        case switchVal(isOn: Bool)
        case selectVal(value: String)
    }
    
    let title: String
    let itemType: ItemType
    var dataType: DataType
    
    init(_ itemType: ItemType, dataType: DataType) {
        self.title = itemType.rawValue
        self.itemType = itemType
        self.dataType = dataType
    }
    
    var widget: SettingsCellProtocol.Type {
        switch dataType {
        case .switchVal:
            SettingsSwitchCell.self
        case .selectVal:
            SettingsSelectCell.self
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }
    
    static func == (lhs: SettingsItem, rhs: SettingsItem) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}
