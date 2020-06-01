//
//  MainViewModel.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/19.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

class MainViewModel: BaseViewModel {
    
    var loadBookCallback: ((CallbackResult) -> Void)?
    var dataList: [BookModel]?
    
    func loadBookList() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.dataList = Database.shared.loadBookList()
            DispatchQueue.main.async {
                self.loadBookCallback?(.success)
            }
        }
    }
}
