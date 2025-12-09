//
//  Task+Ex.swift
//  QuickNote
//
//  Created by zhongshan on 2025/8/18.
//

import Foundation
import Combine

extension Task {
    func eraseToAnyCancellable() -> AnyCancellable {
        AnyCancellable(cancel)
    }
    
    func store(in set: inout Set<AnyCancellable>) {
        set.insert(AnyCancellable(cancel))
    }
}
