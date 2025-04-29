//
//  ReuseIdentifier.swift
//  PoReader
//
//  Created by zhongshan on 2025/4/29.
//

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
