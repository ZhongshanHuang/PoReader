//
//  MainViewController.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/18.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit
import SnapKit

class MainViewController: BaseViewController {

    // MARK: - Properties
    private lazy var viewModel = MainViewModel()
    private var collectionView: UICollectionView!
    private var openFirstBook: Bool = true
    
    private lazy var uploadButon: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "传书", style: .plain, target: self, action: #selector(handleUploadAction(_:)))
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
        title = "土豆阅读"
        setupUI()
        setupViewModel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.loadBookList()
    }
    
    private func setupUI() {
        let uploadButon = UIBarButtonItem(title: "传书", style: .plain, target: self, action: #selector(handleUploadAction(_:)))
        navigationItem.rightBarButtonItem = uploadButon
        
        let flowLayout = UICollectionViewFlowLayout()
        let padding: CGFloat = 20
        let column: CGFloat = 3
        let itemW = (view.frame.width - padding * (column + 1)) / column
        let itemH = itemW * (3 / 2)
        flowLayout.itemSize = CGSize(width: itemW, height: itemH)
        flowLayout.minimumInteritemSpacing = padding
        flowLayout.minimumLineSpacing = padding
        flowLayout.scrollDirection = .vertical
        flowLayout.sectionInset = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = Appearance.backgroundColor
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        collectionView.register(BookCell.self, forCellWithReuseIdentifier: BookCell.identifier)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressAction(_:)))
        collectionView.addGestureRecognizer(longPressGesture)
    }
    
    private func setupViewModel() {
        viewModel.loadBookCallback = { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.collectionView.reloadData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if self.openFirstBook {
                        self.openFirstBook = false
                        self.openBook(at: 0)
                    }
                }
            case .failure:
                debugPrint("加载出错")
            }
        }
    }
    
    private func openBook(at index: Int) {
        guard viewModel.dataList != nil, viewModel.dataList!.count > index else { return }
        let vc = ReaderViewController()
        vc.book = viewModel.dataList?[index]
        navigationController?.pushViewController(vc, animated: true)
        
        // 保存打开时间
        let accessDate = Date().timeIntervalSince1970
        viewModel.dataList?[index].lastAccessDate = accessDate
        let name = viewModel.dataList![index].name
        DispatchQueue.global(qos: .userInitiated).async {
            Database.shared.save(accessDate, forBook: name)
        }
    }
    
    // MARK: - Selector
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
        navigationItem.rightBarButtonItem = uploadButon
        navigationItem.leftBarButtonItem = nil
        
        if selectedIndices.isEmpty {
            collectionView.reloadData()
            return
        }
        
        var toDeleteBooks: Set<BookModel> = []
        toDeleteBooks.reserveCapacity(selectedIndices.count)
        for index in selectedIndices {
            let book = viewModel.dataList![index.item]
            Database.shared.removePageLocation(ofBook: book.name)
            try? FileManager.default.removeItem(at: book.localPath)
            toDeleteBooks.insert(book)
        }
        
        // 如果数组很大，这样删除比较好
        viewModel.dataList?.removeAll(where: { (book) -> Bool in
            return toDeleteBooks.contains(book)
        })
        
        collectionView.performBatchUpdates({
            collectionView.deleteItems(at: selectedIndices.filter({ _ in return true }))
        }) { (_) in
            self.collectionView.reloadData()
        }
        selectedIndices.removeAll()
    }
    
    @objc
    private func handleCancelAction() {
        selectedIndices.removeAll()
        isEditing = false
        collectionView.reloadData()
        
        deleteButon.isEnabled = true
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = uploadButon
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

// MARK: - UICollectionViewDataSource

extension MainViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.dataList?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BookCell.identifier, for: indexPath) as! BookCell
        cell.model = viewModel.dataList?[indexPath.item]
        cell.showEditing = isEditing
        return cell
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

