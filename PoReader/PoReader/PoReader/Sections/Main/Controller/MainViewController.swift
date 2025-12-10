//
//  MainViewController.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/18.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit
import Combine
import SnapKit

class MainViewController: BaseViewController {

    nonisolated
    enum Section: Sendable, Hashable {
        case main
    }
    
    // MARK: - Properties
    private let viewModel = MainViewModel()
    private let flowLayout: UICollectionViewFlowLayout = {
        let flowLayout = UICollectionViewFlowLayout()
        let padding: CGFloat = 20
        let column: CGFloat = 3
        let itemW = (Appearance.minScreenWidth - padding * (column + 1)) / column
        let itemH = itemW * (3 / 2)
        flowLayout.itemSize = CGSize(width: itemW, height: itemH)
        flowLayout.minimumInteritemSpacing = padding
        flowLayout.minimumLineSpacing = padding
        flowLayout.scrollDirection = .vertical
        flowLayout.sectionInset = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        return flowLayout
    }()
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = Appearance.backgroundColor
        collectionView.delegate = self
        return collectionView
    }()
    private var dataSource: UICollectionViewDiffableDataSource<Section, BookModel>!
    private var stores: Set<AnyCancellable> = []
    
    private var openFirstBook: Bool = true
    
    private lazy var uploadButon: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "传书", style: .plain, target: self, action: #selector(handleUploadAction(_:)))
        return button
    }()
    
    private lazy var settingsButon: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "设置", style: .plain, target: self, action: #selector(handleStyleAction(_:)))
        return button
    }()
        
    private lazy var deleteButon: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "删除", style: .plain, target: self, action: #selector(handleConfirmDeleteAction(_:)))
        button.setTitleTextAttributes([.foregroundColor: UIColor.systemRed], for: .normal)
        return button
    }()
    
    private lazy var cancelButon: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "完成", style: .plain, target: self, action: #selector(handleCancelAction))
        return button
    }()
    
    private lazy var selectedIndices: Set<IndexPath> = []
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupUI()
        setupViewModel()
        
        /// 触发网络权限弹窗
        let dataTask = URLSession.shared.dataTask(with: URLRequest(url: URL(string: "https://www.baidu.com")!)) { _, _, _ in
        }
        dataTask.resume()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadData()
    }
    
    private func setupUI() {
        title = "土豆阅读"
        navigationItem.leftBarButtonItem = uploadButon
        navigationItem.rightBarButtonItem = settingsButon
        
        collectionView.register(BookCell.self, forCellWithReuseIdentifier: BookCell.reuseIdentifier)
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { [unowned self] collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BookCell.reuseIdentifier, for: indexPath) as! BookCell
            cell.config(with: itemIdentifier)
            cell.showEditing = isEditing
            return cell
        }
        
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressAction(_:)))
        collectionView.addGestureRecognizer(longPressGesture)
    }
    
    private func updateUI(with data: [BookModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, BookModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(data, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func setupViewModel() {
        viewModel.$dataList.debounce(for: 0.5, scheduler: RunLoop.main).sink { [unowned self] data in
            updateUI(with: data)
        }.store(in: &stores)
        
//        viewModel.$dataList.throttle(for: 0.5, scheduler: RunLoop.main, latest: true).sink { [unowned self] data in
//            updateUI(with: data)
//        }.store(in: &stores)
    }
    
    
    private func loadData() {
        Task {
            do {
                try await viewModel.loadBookList()
                if UserSettings.autoOpenBook, openFirstBook {
                    openFirstBook = false
                    if #available(iOS 16.0, *) {
                        try await Task.sleep(for: .seconds(0.35))
                    } else {
                        try await Task.sleep(nanoseconds: 35 * 1000 * 1000 * 10)
                    }
                    openBook(at: 0)
                }
            } catch {
                openFirstBook = false
                print("书本列表加载出错: \(error.localizedDescription)")
            }
        }
    }
    
    private var transitionDelegate: NavigationTransitionDelegate!
    private func openBook(at index: Int) {
        guard viewModel.dataList.count > index else { return }
        let vc: UIViewController
        switch UserSettings.transitionStyle {
        case .pageCurl:
            let pageVC = PageReaderViewController()
            pageVC.book = viewModel.dataList[index]
            vc = pageVC
        case .scroll:
            let scrollVC = ScrollReaderViewController()
            scrollVC.book = viewModel.dataList[index]
            vc = scrollVC
        }
        
        if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? BookCell {
            transitionDelegate = NavigationTransitionDelegate()
            let animator = OpenBookTransitionAnimationConfig()
            animator.targetView = cell.animationView
            animator.onCompletion = { [unowned self] isPresent in
                if !isPresent {
                    transitionDelegate = nil
                }
            }
            transitionDelegate.set(animatorConfig: animator, for: .push)
            transitionDelegate.set(animatorConfig: animator, for: .pop)
            navigationController?.delegate = transitionDelegate
        }
        navigationController?.pushViewController(vc, animated: true)
        
        // 保存打开时间
        let accessDate = Date().timeIntervalSince1970
        viewModel.update(accessDate, at: index)
    }
    
    // MARK: - Selector
    
    @objc
    private func handleStyleAction(_ sender: UIBarButtonItem) {
        let vc = SettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc
    private func handleUploadAction(_ sender: UIBarButtonItem) {
        let vc = UploaderViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc
    private func handleConfirmDeleteAction(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: nil, message: "删除选中的\(selectedIndices.count)本书", preferredStyle: .actionSheet)
        let confirm = UIAlertAction(title: "删除所选书籍", style: .destructive) { (_) in
            self.handleDeleteAction()
        }
        alert.addAction(confirm)
        let cancel = UIAlertAction(title: "取消", style: .cancel)
        alert.addAction(cancel)
    
        present(alert, animated: true, completion: nil)
    }
    
    private func handleDeleteAction() {
        isEditing = false
        collectionView.allowsMultipleSelection = false
        navigationItem.leftBarButtonItem = uploadButon
        navigationItem.rightBarButtonItem = settingsButon
        
        if selectedIndices.isEmpty {
            collectionView.reloadData()
            return
        }
        
        var toDeleteBooks: Set<BookModel> = []
        toDeleteBooks.reserveCapacity(selectedIndices.count)
        for index in selectedIndices {
            let book = viewModel.dataList[index.item]
            toDeleteBooks.insert(book)
        }
        
        viewModel.remove(toDeleteBooks)
        selectedIndices.removeAll()
    }
    
    @objc
    private func handleCancelAction() {
        selectedIndices.removeAll()
        isEditing = false
        collectionView.reloadData()
        
        deleteButon.isEnabled = true
        navigationItem.leftBarButtonItem = uploadButon
        navigationItem.rightBarButtonItem = settingsButon
    }
    
    @objc
    private func handleLongPressAction(_ sender: UILongPressGestureRecognizer) {
        let local = sender.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: local) else { return }
        isEditing = true
        
        collectionView.allowsMultipleSelection = true
        collectionView.reloadData()
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        selectedIndices.insert(indexPath)
        navigationItem.rightBarButtonItem = deleteButon
        navigationItem.leftBarButtonItem = cancelButon
    }
}

// MARK: - UICollectionViewDelegate

extension MainViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditing {
            selectedIndices.insert(indexPath)
            deleteButon.isEnabled = true
            return
        }
        openBook(at: indexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isEditing {
            selectedIndices.remove(indexPath)
            deleteButon.isEnabled = !selectedIndices.isEmpty
        }
    }
}

class OpenBookTransitionAnimationConfig: NavigationTransitionAnimationConfigurable {
    var duration: TimeInterval { 3 }
    var auxAnimations: ((Bool) -> [AuxAnimation])? { nil }
    var onCompletion: ((Bool) -> Void)?
    var targetView: UIView!
    
    private var coverView: UIView?
    private var contentView: UIView?
    
    func layout(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {
        var sublayerTransform = CATransform3DIdentity
        sublayerTransform.m34 = -1.0 / 500
        container.layer.sublayerTransform = sublayerTransform
        if presenting {
            let targetRect = targetView.convert(targetView.frame, to: fromView)
            let coverView = getSnapshotView(from: targetView)
            coverView.isOpaque = true
            coverView.layer.anchorPoint = CGPoint(x: 0, y: 0.5)
            coverView.frame = targetRect
            let contentView = getSnapshotView(from: toView)
            contentView.frame = targetRect
            container.addSubview(contentView)
            container.addSubview(coverView)
            
            targetView.isHidden = true
            toView.isHidden = true
            
            self.coverView = coverView
            self.contentView = contentView
        } else {
            let coverView = getSnapshotView(from: targetView)
            coverView.isOpaque = true
            coverView.layer.anchorPoint = CGPoint(x: 0, y: 0.5)
            coverView.frame = fromView.frame
            coverView.transform3D = CATransform3DMakeRotation(-.pi / 2, 0, 1, 0)
            let contentView = getSnapshotView(from: fromView)
            contentView.frame = fromView.frame
            container.addSubview(contentView)
            container.addSubview(coverView)
            
            targetView.isHidden = true
            fromView.isHidden = true
            
            self.coverView = coverView
            self.contentView = contentView
        }
    }
    
    func animations(presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {
        if presenting {
            coverView?.frame = toView.frame
            contentView?.frame = toView.frame
            coverView?.transform3D = CATransform3DMakeRotation(-.pi / 2, 0, 1, 0)
        } else {
            let targetRect = targetView.convert(targetView.frame, to: toView)
            coverView?.frame = targetRect
            contentView?.frame = targetRect
            coverView?.transform3D = CATransform3DIdentity
        }
    }
    
    func completeTransition(didComplete: Bool, presenting: Bool, fromView: UIView, toView: UIView, in container: UIView) {
        targetView.isHidden = false
        coverView?.removeFromSuperview()
        coverView = nil
        contentView?.removeFromSuperview()
        contentView = nil
        if presenting {
            toView.isHidden = false
        } else {
            fromView.isHidden = false
        }
        onCompletion?(presenting)
    }
    
    private func getSnapshotView(from: UIView) -> UIImageView {
        let imageView = UIImageView()
        let render = UIGraphicsImageRenderer(size: from.frame.size, format: .preferred())
        imageView.image = render.image { ctx in
            let isHidden = from.isHidden
            if isHidden {
                from.isHidden = false
            }
            from.layer.render(in: ctx.cgContext)
            from.isHidden = isHidden
        }
        return imageView
    }
    
}
