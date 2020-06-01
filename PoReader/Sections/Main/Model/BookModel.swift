//
//  BookModel.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/19.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

struct BookModel: BookResourceProtocal {
    var name: String
    var localPath: URL
    var lastAccessDate: Double
    var progress: Double
}

extension BookModel: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
