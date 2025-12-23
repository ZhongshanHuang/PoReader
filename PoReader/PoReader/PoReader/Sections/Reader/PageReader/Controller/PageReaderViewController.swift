import UIKit

protocol BookResourceProtocal {
    var name: String { get }
    var localPath: URL { get }
}

class PageReaderViewController: BaseViewController {
    
    // MARK: - Properties
    var book: (any BookResourceProtocal)?
    
    private lazy var pageViewController: UIPageViewController = {
        let page = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal, options: nil)
        page.isDoubleSided = true
        page.dataSource = self
        if page.gestureRecognizers.count > 1 && page.gestureRecognizers[1] is UITapGestureRecognizer {
            page.gestureRecognizers[1].isEnabled = false // 屏蔽自带的单击手势
        }
        return page
    }()
    private let dataSource = ReaderDataSource()
    private let bottomBar = ReaderBottomBar()
    private var hideStatusBar = true
    
    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
        setupDataSource()
        registerForNotification()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePageLocation()
    }
    
    private func setupUI() {
        title = book?.name.components(separatedBy: ".").first
        poNavigationBarConfig.isHidden = true
        
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
            let height: CGFloat = (UIApplication.shared.currentKeyWindow?.safeAreaInsets.bottom ?? 0) + 110
            make.height.equalTo(height)
        }
    }
    
    // 观察应用事件，保存当前文章页码
    private var observer: (any NSObjectProtocol)?
    private func registerForNotification() {
        observer = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.savePageLocation()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] _ in
            self?.savePageLocation()
        }
    }
    
    private func setupDataSource() {
        dataSource.name = book?.name
        dataSource.sourcePath = book?.localPath
        
        dataSource.parseChapter()
        if let book = self.book {
            let pageLocation = try? Database.shared.pageLocation(forBook: book.name)
            self.showPageItem(atChapter: pageLocation?.chapterIndex ?? 0, subrangeIndex: pageLocation?.subrangeIndex ?? 0)
        }
    }
    
    private func showPageItem(atChapter chapterIndex: Int, subrangeIndex: Int, animated: Bool = false) {
        if let pageDisplayItem = pageDisplayItem(atChapter: chapterIndex, subrangeIndex: subrangeIndex) {
            pageViewController.setViewControllers([pageDisplayItem], direction: .forward, animated: animated, completion: nil)
        }
    }
    
    private func showNextPage() {
        guard let currentPage = pageViewController.viewControllers?.first as? PageReaderDisplayCell,
            let currentReverse = pageViewController(pageViewController, viewControllerAfter: currentPage),
            let next = pageViewController(pageViewController, viewControllerAfter: currentReverse) else { return }
        // the latter view controller is used as the back
        pageViewController.setViewControllers([next, currentReverse], direction: .forward, animated: true, completion: nil)
    }
    
    // MARK: - Selector
    @objc
    private func savePageLocation() {
        guard let currentPage = (pageViewController.viewControllers?.first as? PageReaderDisplayCell)?.pageItem,
            let book = book else { return }
        let pageLocal = PageLocation(chapterIndex: currentPage.chapterIndex, subrangeIndex: currentPage.subrangeIndex, progress: Double(currentPage.progress))
        try? Database.shared.updatePageLocation(pageLocal, forBook: book.name)
    }
    
    @objc
    private func showOrHideBar() {
        let hidden = poNavigationBarConfig.isHidden ?? false
        let duration = TimeInterval(UINavigationController.hideShowBarDuration)
        
        if hidden { // 当前隐藏状态
            bottomBar.isHidden = false
            if let currentPage = (pageViewController.viewControllers?.first as? PageReaderDisplayCell)?.pageItem {
                bottomBar.progress = currentPage.progress
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
        poNavigationBarConfig.isHidden = !hidden
        flushBarConfigure(true)
    }
    
    // MARK: - Touches
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let hidden = navigationController?.navigationBar.isHidden ?? false
        if !hidden {
            showOrHideBar()
            return
        }
        
        let centerX = view.frame.width / 2
        let centerXEnable = view.frame.width / 4
        let centerY = view.frame.height / 2
        let centerYEnable = view.frame.height / 4
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

// MARK: - UIPageViewControllerDataSource

extension PageReaderViewController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let pageItem = (viewController as? PageReaderDisplayCell)?.pageItem {
            if pageItem.subrangeIndex == 0 {
                if pageItem.chapterIndex == 0 {
                    return nil
                } else {
                    let chapter = dataSource.chapters[pageItem.chapterIndex - 1]
                    return reversePageDisplayItem(atChapter: pageItem.chapterIndex - 1, subrangeIndex: chapter.subranges.count - 1)
                }
            }
            return reversePageDisplayItem(atChapter: pageItem.chapterIndex, subrangeIndex: pageItem.subrangeIndex - 1)
        } else if let reverseItem = viewController as? ReversePageReaderDisplayItem {
            
            return pageDisplayItem(atChapter: reverseItem.chapterIndex, subrangeIndex: reverseItem.subrangeIndex)
        } else {
            return nil
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let reverseItem = viewController as? ReversePageReaderDisplayItem {
            let chapter = dataSource.chapters[reverseItem.chapterIndex]
            if reverseItem.subrangeIndex >= chapter.subranges.count - 1 {
                if reverseItem.chapterIndex >= dataSource.chapters.count - 1 {
                    return nil
                } else {
                    return pageDisplayItem(atChapter: reverseItem.chapterIndex + 1, subrangeIndex: 0)
                }
            }
            return pageDisplayItem(atChapter: reverseItem.chapterIndex, subrangeIndex: reverseItem.subrangeIndex + 1)
        } else if let pageItem = (viewController as? PageReaderDisplayCell)?.pageItem {
            return reversePageDisplayItem(atChapter: pageItem.chapterIndex, subrangeIndex: pageItem.subrangeIndex)
        } else {
            return nil
        }
    }
    
    /// 获取一个页的反面，不添加反面页的话暗黑模式时 反面会显示白色刺眼 O(1)
    /// - Parameters:
    ///   - chapterIndex: 章节索引
    ///   - subrangeIndex: 章节内部分页索引
    /// - Returns: reversePageItem
    private func reversePageDisplayItem(atChapter chapterIndex: Int, subrangeIndex: Int) -> ReversePageReaderDisplayItem? {
        let reverseItem = ReversePageReaderDisplayItem()
        reverseItem.chapterIndex = chapterIndex
        reverseItem.subrangeIndex = subrangeIndex
        return reverseItem
    }
    
    private func pageDisplayItem(atChapter chapterIndex: Int, subrangeIndex: Int) -> PageReaderDisplayCell? {
        if let pageItem = dataSource.pageItem(atChapter: chapterIndex, subrangeIndex: subrangeIndex) {
            return PageReaderDisplayCell(pageItem: pageItem)
        }
        return nil
    }
}

// MARK: - ReaderBottomBarDelegate

extension PageReaderViewController: ReaderBottomBarDelegate {
    
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didClickButton type: ReaderBottomBar.TouchEventType) {
        if (type == .progressForward || type == .progressBackward) {
            var currentProgress = bottomBar.progress
            if (type == .progressForward) {
                if currentProgress < 0.001 { return }
                currentProgress -= 0.001
            } else {
                if currentProgress > 0.999 { return }
                currentProgress += 0.001
            }
            bottomBar.progress = currentProgress
            
            if let chapter = dataSource.chapters.last {
                let totalLength = chapter.range.upperBound - 1
                let location = currentProgress * Float(totalLength)
                if let (chapterIndex, subrangeIndex) = dataSource.searchPageLocation(location: Int(location)) {
                    showPageItem(atChapter: chapterIndex, subrangeIndex: subrangeIndex)
                }
            }
            return;
        }
        
        if (type == .fontDecrease || type == .fontIncrease) {
            var currentSize = Appearance.fontSize
            if (type == .fontDecrease) {
                if currentSize < 10 { return }
                currentSize -= 1
            } else if (type == .fontIncrease) {
                if currentSize > 28 { return }
                currentSize += 1
            }
            Appearance.fontSize = currentSize
            guard let currentPage = (pageViewController.viewControllers?.first as? PageReaderDisplayCell)?.pageItem,
                let sublocation = dataSource.chapterSublocation(atChapter: currentPage.chapterIndex, subrangeIndex: currentPage.subrangeIndex) else { return }
            
            dataSource.updateChapterSubrange()
            guard let subrangeIndex = dataSource.chapterSubrangeIndex(atChapter: currentPage.chapterIndex, sublocation: sublocation) else { return }
            
            showPageItem(atChapter: currentPage.chapterIndex, subrangeIndex: subrangeIndex)
        }
    }
        
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didChangeProgressTo value: Float) {
        if let chapter = dataSource.chapters.last {
            let totalLength = chapter.range.upperBound - 1
            let location = value * Float(totalLength)
            if let (chapterIndex, subrangeIndex) = dataSource.searchPageLocation(location: Int(location)) {
                showPageItem(atChapter: chapterIndex, subrangeIndex: subrangeIndex)
            }
        }
    }
    
}


