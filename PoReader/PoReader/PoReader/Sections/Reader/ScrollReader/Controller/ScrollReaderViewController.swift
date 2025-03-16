//
//  ScrollReaderViewController.swift
//  PoReader
//
//  Created by HzS on 2022/10/19.
//

import UIKit
import SnapKit

extension ScrollReaderViewController {
    enum LoadState {
        case idle
        case loading
        case noMore
    }
}

class ScrollReaderViewController: BaseViewController {
    
    // MARK: - Properties
    var book: (any BookResourceProtocal)?

    private let dataSource = ReaderDataSource()
    private let bottomBar = ReaderBottomBar()
    private var hideStatusBar = true
    private var dataList: [ChapterModel] = []
    private var nextLoadState: LoadState = .idle
    private var previousLoadState: LoadState = .idle
    private var isDragUp: Bool = true
    private var isFirstDidAppear: Bool = true
    
    private let flowLayout: UICollectionViewFlowLayout = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = Appearance.lineSpacing
        flowLayout.sectionInset.top = Appearance.displayRect.minY
        return flowLayout
    }()
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = Appearance.readerBackgroundColor
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.scrollsToTop = false
        collectionView.register(ScrollReaderDisplayCell.self, forCellWithReuseIdentifier: ScrollReaderDisplayCell.identifier)
        return collectionView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupDataSource()
        setupUI()
        registerForNotification()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isFirstDidAppear { return }
        
        isFirstDidAppear = true
        if let book = self.book {
            let pageLocation = Database.shared.pageLocation(forBook: book.name)
            if pageLocation.subrangeIndex < dataList[0].subranges.count {
                collectionView.setContentOffset(CGPoint(x: 0, y: dataList[0].subrangeHeight(before: pageLocation.subrangeIndex)), animated: true)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePageLocation()
    }
    
    private func setupUI() {
        title = book?.name.components(separatedBy: ".").first
        
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
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
        
        poNavigationBarConfig.isHidden = true
    }
    
    private func setupDataSource() {
        dataSource.name = book?.name
        dataSource.sourcePath = book?.localPath
        
        dataSource.parseChapter()
        if let book = self.book {
            let pageLocation = Database.shared.pageLocation(forBook: book.name)
            showPageItem(chapterIndex: pageLocation.chapterIndex, subrangeIndex: pageLocation.subrangeIndex)
        }
    }
    
    private func showPageItem(chapterIndex: Int, subrangeIndex: Int) {
        if chapterIndex >= (dataSource.chapters?.count ?? 0) || subrangeIndex >= dataSource.chapters![chapterIndex].subranges.count { return }
        
        // 为保持章节顺序，必须先清除原来的章节
        dataList.removeAll()
        
        if let chapter = dataSource.chapters?[chapterIndex] {
            dataList.append(chapter)
            if subrangeIndex >= chapter.subranges.count - 2, chapter.idx + 1 < dataSource.chapters!.count {
                dataList.append(dataSource.chapters![chapter.idx + 1])
            }
            collectionView.reloadData()
            collectionView.setContentOffset(CGPoint(x: 0, y: dataList[0].subrangeHeight(before: subrangeIndex)), animated: false)
        }
    }
    
    // 观察应用事件，保存当前文章页码
    private func registerForNotification() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] (_) in
            self?.savePageLocation()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] (_) in
            self?.savePageLocation()
        }
    }
    
    // MARK: - Selector
    @objc
    private func savePageLocation() {
        guard let currentPage = (collectionView.visibleCells.last as? ScrollReaderDisplayCell)?.pageItem,
            let book = book else { return }
        let pageLocal = PageLocation(chapterIndex: currentPage.chapterIndex, subrangeIndex: currentPage.subrangeIndex, progress: Double(currentPage.progress))
        Database.shared.save(pageLocal, forBook: book.name)
    }
    
    @objc
    private func showOrHideBar() {
        let hidden = poNavigationBarConfig.isHidden ?? false
        let duration = TimeInterval(UINavigationController.hideShowBarDuration)

        if hidden { // 当前隐藏状态
            bottomBar.isHidden = false
            
            if let currentPage = (collectionView.visibleCells.first as? ScrollReaderDisplayCell)?.pageItem {
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

        hideStatusBar = !hidden
        setNeedsStatusBarAppearanceUpdate()
        poNavigationBarConfig.isHidden = !hidden
        flushBarConfigure(true)
    }

    // MARK: - Touches

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        showOrHideBar()
    }

    // MARK - States bar
    override var prefersStatusBarHidden: Bool {
        return hideStatusBar
    }
    
}

extension ScrollReaderViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return dataList.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let count = dataList[section].subranges.count
        return count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ScrollReaderDisplayCell.identifier, for: indexPath) as! ScrollReaderDisplayCell
        let chapter = dataList[indexPath.section]
        let pageItem = dataSource.pageItem(atChapter: chapter.idx, subrangeIndex: indexPath.item)
        cell.pageItem = pageItem
        return cell
    }

}

extension ScrollReaderViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = dataList[indexPath.section].subSize(at: indexPath.item).height
        return CGSize(width: view.bounds.width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showOrHideBar()
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        isDragUp = velocity.y >= 0
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset
        if isDragUp { // next
            if nextLoadState != .idle { return }
            
            // 还有1屏内容时预解析下一章节
            if offset.y >= scrollView.contentSize.height - scrollView.bounds.height * 2 {
                print("触发上拉")
                if let currentChapter = dataList.last {
                    if currentChapter.idx + 1 < dataSource.chapters!.count {
                        dataList.append(dataSource.chapters![currentChapter.idx + 1])
                        collectionView.reloadData()
                    } else {
                        nextLoadState = .noMore
                    }
                }
            }
        } else { // previous
            if previousLoadState != .idle { return }
            
            // 还有1屏内容时预解析上一章节
            if offset.y <= scrollView.bounds.height {
                print("触发下拉")
                if let currentChapter = dataList.first {
                    if currentChapter.idx - 1 >= 0 {
                        let previousChapter = dataSource.chapters![currentChapter.idx - 1]
                        dataList.insert(previousChapter, at: 0)
                        collectionView.reloadData()
                        collectionView.contentOffset = CGPoint(x: offset.x, y: offset.y + previousChapter.totalSubrangeHeight())
                    } else {
                        previousLoadState = .noMore
                    }
                }
            }
        }
        
    }
    
}

// MARK: - ReaderBottomBarDelegate

extension ScrollReaderViewController: ReaderBottomBarDelegate {
    
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

            if let chapter = dataSource.chapters?.last {
                let totalLength = chapter.range.upperBound - 1
                let location = currentProgress * Float(totalLength)
                if let (chapterIndex, subrangeIndex) = dataSource.searchPageLocation(location: Int(location)) {
                    showPageItem(chapterIndex: chapterIndex, subrangeIndex: subrangeIndex)
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
            guard let currentPage = (collectionView.visibleCells.last as? ScrollReaderDisplayCell)?.pageItem,
                let sublocation = dataSource.chapterSublocation(atChapter: currentPage.chapterIndex, subrangeIndex: currentPage.subrangeIndex) else { return }

            dataSource.updateChapterSubrange()
            guard let subrangeIndex = dataSource.chapterSubrangeIndex(atChapter: currentPage.chapterIndex, sublocation: sublocation) else { return }

            showPageItem(chapterIndex: currentPage.chapterIndex, subrangeIndex: subrangeIndex)
        }
    }
        
    func readerBottomBar(_ bottomBar: ReaderBottomBar, didChangeProgressTo value: Float) {
        if let chapter = dataSource.chapters?.last {
            let totalLength = chapter.range.upperBound - 1
            let location = value * Float(totalLength)
            if let (chapterIndex, subrangeIndex) = dataSource.searchPageLocation(location: Int(location)) {
                showPageItem(chapterIndex: chapterIndex, subrangeIndex: subrangeIndex)
            }
        }
    }
    
}

