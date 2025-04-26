//
//  GestureRecognizer.swift
//  KitDemo
//
//  Created by 黄中山 on 2018/5/21.
//  Copyright © 2018年 黄中山. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

class GestureRecognizer: UIGestureRecognizer {
    
    public enum State {
        case began
        case moved
        case ended
        case cancelled
    }
    
    // MARK: - Properties-[public]
    public private(set) var startPoint: CGPoint = .zero /// start point
    public private(set) var lastPoint: CGPoint = .zero /// last move point
    public private(set) var currentPoint: CGPoint = .zero /// current move point
    
    /// The action closure invoked by every gesture event
    public var action: ((GestureRecognizer, GestureRecognizer.State) -> Void)?
    
    
    // MARK - Methods - [public]
    public func cancel() {
        if state == .began || state == .changed {
            state = .cancelled
            action?(self, .cancelled)
        }
    }
    
    // MARK - Methods - [override]
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .began
        startPoint = touches.first?.location(in: view) ?? .zero
        currentPoint = startPoint
        action?(self, .began)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .changed
        currentPoint = touches.first?.location(in: view) ?? .zero
        action?(self, .moved)
        lastPoint = currentPoint
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .ended
        action?(self, .ended)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
        action?(self, .cancelled)
    }
    
    public override func reset() {
        state = .possible
    }
}
