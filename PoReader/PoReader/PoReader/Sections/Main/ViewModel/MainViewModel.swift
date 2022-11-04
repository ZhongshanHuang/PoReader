//
//  MainViewModel.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/19.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

class MainViewModel: BaseViewModel {
    var dataList: [BookModel]?
    
    func loadBookList(completion: @escaping (CallbackResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.dataList = Database.shared.loadBookList()
            DispatchQueue.main.async {
                completion(.success)
            }
        }
    }
}
