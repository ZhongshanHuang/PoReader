import UIKit

extension UIApplication {
    var currentKeyWindow: UIWindow? {
        connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).last
    }
}

extension UIFont{
    static func pingfang(ofSize fontSize: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont(name: weight.familyName, size:fontSize) ?? UIFont.systemFont(ofSize: fontSize, weight: weight)
    }
}

private extension UIFont.Weight {
    var familyName: String {
        switch self {
        case .thin:
            "PingFangSC-Thin"
        case .light:
            "PingFangSC-Light"
        case .regular:
            "PingFangSC-Regular"
        case .medium:
            "PingFangSC-Medium"
        case .semibold:
            "PingFangSC-Semibold"
        case .bold:
            "PingFangSC-Bold"
        case .heavy:
            "PingFangSC-Heavy"
        case .black:
            "PingFangSC-Black"
        default:
            fatalError()
        }
    }
}
