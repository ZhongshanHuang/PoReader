import UIKit

protocol ReuseIdentifier: AnyObject {
    static var reuseIdentifier: String { get }
}

extension ReuseIdentifier {
    static var reuseIdentifier: String { String(describing: self) }
}

extension UITableViewCell: ReuseIdentifier {}
extension UITableViewHeaderFooterView: ReuseIdentifier {}
extension UICollectionReusableView: ReuseIdentifier {}
