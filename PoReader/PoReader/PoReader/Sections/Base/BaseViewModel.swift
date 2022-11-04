//
//  BaseViewModel.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/19.
//  Copyright © 2020 potato. All rights reserved.
//

import Foundation

class BaseViewModel {
    
    enum CallbackResult {
        case success
        case failure
    }
    
    enum CallbackDataResult<T> {
        case success(T)
        case failure
    }
}
