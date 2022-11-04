//
//  Recyclable.swift
//  PoSQLiteDemo
//
//  Created by HzS on 2022/8/15.
//

import Foundation

final class Recyclable<Value> {
    typealias OnRecycled = () -> Void
    final let rawValue: Value
    let onRecycled: OnRecycled?
    
    init(_ rawValue: Value, onRecycled: OnRecycled? = nil) {
        self.rawValue = rawValue
        self.onRecycled = onRecycled
    }
    
    deinit {
        onRecycled?()
    }
}
