//
//  ReaderViewController.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/18.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

protocol BookResourceProtocal {
    var name: String { get }
    var localPath: URL { get }
}

class ReaderViewController: BaseViewController {
    
    // MARK: - Properties
    var book: BookResourceProtocal?
    
    private lazy var pageViewController: UIPageViewController = {
        let page = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal, options: nil)
        page.dataSource = dataSource
        page.isDoubleSided = true
        page.gestureRecognizers[1].isEnabled = false // 屏蔽自带的单击手势
        return page
    }()
    private lazy var dataSource = PageViewControllerDataSource()
    private lazy var bottomBar = ReaderBottomBar()
    private var hideStatusBar = true
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
        setupDataSource()
        dataSource.parseChapter()
        
        if let book = book {
            let pageLocation = Database.shared.pageLocation(forBook: book.name)
            showPageItem(atChapter: pageLocation.chapterIndex, subrangeIndex: pageLocation.subrangeIndex)
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] (_) in
            self?.savePageLocation()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePageLocation()
    }
    
    private func setupUI() {
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        pageViewController.view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        bottomBar.isHidden = true
        bottomBar.delegate = self
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints { (make) in
            make.left.bottom.right.equalToSuperview()
            let height: CGFloat = UIDevice.isNotch ? 120 : 100
            make.height.equalTo(height)
        }
        
        navigationBarConfigure.isHidden = true
        
        // 观察应用退出事件，保存当前文章页码
        NotificationCenter.default.addObserver(self, selector: #selector(savePageLocation), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    private func setupDataSource() {
        dataSource.name = book?.name
        dataSource.sourcePath = book?.localPath
    }
    
    @objc
    private func showOrHideBar() {
        let hidden = navigationBarConfigure.isHidden ?? false
        let duration = TimeInterval(UINavigationController.hideShowBarDuration)
        
        if hidden { // 当前隐藏状态
            bottomBar.isHidden = false
            if let currentPage = pageViewController.viewControllers?.first as? PageItem {
                bottomBar.progress = dataSource.progress(atChapter: currentPage.chapterIndex, subrangeIndex: currentPage.subrangeIndex)
            }
            
            UIView.animate(withDuration: duration, animations: {
                self.bottomBar.snp.updateConstraints { (make) in
                    make.bottom.equalToSuperview()
                }
                self.bottomBar.superview?.layoutIfNeeded()
            }, completion: nil)
            
        } else {
            let bottomBarH = bottomBar.frame.height
            UIView.animate(withDuration: duration, animations: {
                self.bottomBar.snp.updateConstraints { (make) in
                    make.bottom.equalToSuperview().offset(bottomBarH)
                }
                self.bottomBar.superview?.layoutIfNeeded()
            }) { (_) in
                self.bottomBar.isHidden = true
            }
        }
        
        pageViewController.gestureRecognizers[0].isEnabled = !hidden

        hideStatusBar = !hidden
        setNeedsStatusBarAppearanceUpdate()
        navigationBarConfigure.isHidden = !hidden
        flushBarConfigure(true)
    }
    
    private func showPageItem(atChapter chapterIndex: Int, subrangeIndex: Int, animated: Bool = false) {
        guard let item = dataSource.pageItem(atChapter: chapterIndex, subrangeIndex: subrangeIndex) else { return }
        pageViewController.setViewControllers([item], direction: .forward, animated: animated, completion: nil)
    }
    
    private func showNextPage() {
        guard let currentPage = pageViewController.viewControllers?.first as? PageItem,
            let currentReverse = dataSource.pageViewController(pageViewController, viewControllerAfter: currentPage),
            let next = dataSource.pageViewController(pageViewController, viewControllerAfter: currentReverse) else { return }
        // the latter view controller is used as the back
        pageViewController.setViewControllers([next, currentReverse], direction: .forward, animated: true, completion: nil)
    }
    
    // MARK: - Selector
    @objc
    private func savePageLocation() {
        guard let currentPage = pageViewController.viewControllers?.first as? PageItem,
            let book = book else { return }
        let pageLocal = PageLocation(chapterIndex: currentPage.chapterIndex, subrangeIndex: currentPage.subrangeIndex, progress: Double(currentPage.progress))
        Database.shared.save(pageLocal, forBook: book.name)
    }
    
    // MARK: - Touches
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let hidden = navigationController?.navigationBar.isHidden ?? false
        if !hidden {
            showOrHideBar()
            return
        }
        
        let centerX = view.frame.width / 2
        let centerXEnable = view.frame.width / 6
        let centerY = view.frame.height / 2
        let centerYEnable = view.frame.height / 6
        let local = touches.first!.location(in: view)
        
        if local.x < centerX - centerXEnable || local.x > centerX + centerXEnable ||
            local.y > centerY + centerYEnable || local.y < centerY - centerYEnable { // 左右两边点击 跳转下一页
            showNextPage()
        } else {
            showOrHideBar()
        }
    }
    
    // MARK - States bar
    override var prefersStatusBarHidden: Bool {
        return hideStatusBar
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
}

// MARK: - ReaderBottomBarDelegate

extension ReaderViewController: ReaderBottomBarDelegate {
    
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didClickProgressButton type: ReaderBottomBar.ProgressButtonType) {
        var currentProgress = bottomBar.progress
        switch type {
        case .forward:
            if currentProgress < 0.001 { return }
            currentProgress -= 0.001
        case .backward:
            if currentProgress > 0.999 { return }
            currentProgress += 0.001
        }
        bottomBar.progress = currentProgress
        
        if let chapter = dataSource.chapters?.last {
            let totalLength = chapter.range.upperBound - 1
            let location = currentProgress * Float(totalLength)
            if let (chapterIndex, subrangeIndex) = dataSource.searchPageLocation(location: Int(location)) {
                showPageItem(atChapter: chapterIndex, subrangeIndex: subrangeIndex)
            }
        }
    }
    
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didClickFontButton type: ReaderBottomBar.FontButtonType) {
        var currentSize = Appearance.fontSize
        switch type {
        case .smaller:
            if currentSize < 10 { return }
            currentSize -= 1
        case .bigger:
            if currentSize > 28 { return }
            currentSize += 1
        }
        Appearance.fontSize = currentSize
        guard let currentPage = pageViewController.viewControllers?.first as? PageItem,
            let sublocation = dataSource.chapterSublocation(atChapter: currentPage.chapterIndex, subrangeIndex: currentPage.subrangeIndex) else { return }
        
        dataSource.updateChapterSubrange()
        guard let subrangeIndex = dataSource.chapterSubrangeIndex(atChapter: currentPage.chapterIndex, sublocation: sublocation) else { return }
        
        showPageItem(atChapter: currentPage.chapterIndex, subrangeIndex: subrangeIndex)
    }
    
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didChangeProgressTo value: Float) {
        if let chapter = dataSource.chapters?.last {
            let totalLength = chapter.range.upperBound - 1
            let location = value * Float(totalLength)
            if let (chapterIndex, subrangeIndex) = dataSource.searchPageLocation(location: Int(location)) {
                showPageItem(atChapter: chapterIndex, subrangeIndex: subrangeIndex)
            }
        }
    }
    
}


