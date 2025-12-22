import UIKit

enum SettingsCellEventType {
    case switchClick(isOn: Bool)
    case selectClick
}

protocol SettingsCellProtocol: UITableViewCell {
    var onEvent: ((SettingsCellEventType) -> Void)? { get set }
    func config(with data: SettingsItem)
}
