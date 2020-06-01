//
//  PoSentinel.swift
//  KitDemo
//
//  Created by 黄中山 on 2018/5/24.
//  Copyright © 2018年 黄中山. All rights reserved.
//

import Foundation

struct PoSentinel {
    
    // MARK: - Properties
    private var _value: Int = 0
    
    private mutating func _valuePtr() -> UnsafeMutablePointer<Int> {
        withUnsafeMutablePointer(to: &_value) { (ptr) -> UnsafeMutablePointer<Int> in
            return ptr
        }
    }
    
    // MARK: - Initializers
    init(value: Int = 0) {
        self._value = value
    }
    
    // MARK: - Methods
    @discardableResult
    mutating func value() -> Int {
        _swift_stdlib_atomicLoadInt(object: _valuePtr())
    }
    
    @discardableResult
    mutating func increase() -> Int {
        _swift_stdlib_atomicFetchAddInt(object: _valuePtr(), operand: 1)
    }
}
