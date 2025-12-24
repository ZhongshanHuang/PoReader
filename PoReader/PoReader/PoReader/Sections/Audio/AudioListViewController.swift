import UIKit
import Combine

class AudioListViewController: BaseViewController {
    enum Section {
        case main
    }
    
    private let viewModel = AudioListViewModel()
    
    private lazy var uploadButon: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "传书", style: .plain, target: self, action: #selector(handleUploadAction(_:)))
        return button
    }()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, AudioModel>!
    private var stores: Set<AnyCancellable> = []
    private var currentIndexPath: IndexPath?
    private let playerView = AudioPlayerView()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationItem.title = "土豆阅读"
        navigationItem.leftBarButtonItem = uploadButon
        
        setupView()
        configureDataSource()
        setupViewModel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadData()
    }
    
    private func setupView() {
        playerView.alpha = 0
        view.addSubview(playerView)
        playerView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(0)
        }
        
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        if #available(iOS 15.0, *) {
            config.headerTopPadding = 0
        }
        config.trailingSwipeActionsConfigurationProvider = { [unowned self] (indexPath) in
            trailingSwipeActionConfigurationForListCellItem(at: indexPath)
        }
        
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(playerView.snp.top)
        }
        
        playerView.onStop = { [weak self] (model, progress) in
            guard let self, let model else { return }
            currentIndexPath = nil
            viewModel.updateProgress(TimeInterval(progress), forAudio: model.name)
            var snapshot = dataSource.snapshot()
            if let idx = snapshot.itemIdentifiers.firstIndex(where: { $0.id == model.id }) {
                snapshot.itemIdentifiers[idx].progress = TimeInterval(progress)
                if #available(iOS 15.0, *) {
                    snapshot.reconfigureItems([snapshot.itemIdentifiers[idx]])
                } else {
                    snapshot.reloadItems([snapshot.itemIdentifiers[idx]])
                }
                dataSource.apply(snapshot, animatingDifferences: true)
            }
            showPlayer(false)
        }
    }
    
    private func setupViewModel() {
        viewModel.$dataList.debounce(for: 0.35, scheduler: RunLoop.main).sink { [unowned self] data in
            updateUI(with: data)
        }.store(in: &stores)
    }
    
    private func updateUI(with data: [AudioModel], animated: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, AudioModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(data, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<AudioListCell, AudioModel> { (cell, indexPath, item) in
            cell.config(with: item, isSelected: self.currentIndexPath == indexPath)
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, AudioModel>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, item: AudioModel) -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }
    
    private func trailingSwipeActionConfigurationForListCellItem(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let starAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] (_, _, completion) in
            guard let self = self else {
                completion(false)
                return
            }
            if currentIndexPath == indexPath {
                playerView.stop()
            }
            viewModel.removeItem(at: indexPath.item)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [starAction])
    }
    
    private func loadData() {
        Task {
            do {
                try await viewModel.loadAudioList()
            } catch {
                print("音频列表加载出错: \(error.localizedDescription)")
            }
        }
    }
    
    private func showPlayer(_ show: Bool) {
        if (show && playerView.alpha == 1) || (!show && playerView.alpha == 0) {
            return
        }
        
        playerView.snp.updateConstraints { make in
            make.height.equalTo(show ? 65 : 0)
        }
        
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
            self.playerView.alpha = show ? 1 : 0
        }
    }
    
    // MARK: - Selectors
    @objc
    private func handleUploadAction(_ sender: UIBarButtonItem) {
        let vc = UploaderViewController(uploadType: .audio)
        navigationController?.pushViewController(vc, animated: true)
        
        // 跳上传界面时关闭播放器
        playerView.stop()
    }

}

// MARK: - UICollectionViewDelegate
extension AudioListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if indexPath == currentIndexPath { return }
        var snapshot = dataSource.snapshot()
        let model = snapshot.itemIdentifiers[indexPath.item]
        // 保存上一个的进度
        if let lastModel = playerView.currentModel {
            viewModel.updateProgress(TimeInterval(playerView.progressValue), forAudio: lastModel.name)
        }
        
        let progress = viewModel.progress(forAudio: model.name)
        playerView.play(with: model, progress: progress ?? 0)
        showPlayer(true)
        
        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems([model])
        } else {
            snapshot.reloadItems([model])
        }
        currentIndexPath = indexPath
        dataSource.apply(snapshot, animatingDifferences: true)
        
        // 保存打开时间
        let accessDate = Date().timeIntervalSince1970
        viewModel.updateAccessDate(accessDate, forAudio: model.name)
    }
}
