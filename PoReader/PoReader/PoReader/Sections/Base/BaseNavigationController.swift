//
//  BaseNavigationController.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/26.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit
import PoNavigationBar

class BaseNavigationController: PoNavigationController {

    // 返回按钮
    private lazy var backBtn: UIButton = {
        // 设置返回按钮属性
        let backBtn = UIButton(type: .system)
        backBtn.setImage(UIImage(named: "navigation_back_white"), for: .normal)
        backBtn.titleLabel?.isHidden = true
        backBtn.addTarget(self, action: #selector(BaseNavigationController.backBtnClick), for: .touchUpInside)
        backBtn.contentHorizontalAlignment = .left
        backBtn.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        return backBtn
    }()
    
    @objc
    private func backBtnClick() {
        popViewController(animated: true)
    }
    
    /// Push
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if !children.isEmpty {
            viewController.hidesBottomBarWhenPushed = true
            let backBarButtonItem = UIBarButtonItem(image: UIImage(named: "navigation_back_white"), style: .plain, target: self, action: #selector(backBtnClick))
            backBarButtonItem.imageInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 0)
            viewController.navigationItem.leftBarButtonItem = backBarButtonItem
        }
        super.pushViewController(viewController, animated: true)
    }
}
