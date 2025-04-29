//
//  SettingsViewController.swift
//  PoReader
//
//  Created by zhongshan on 2025/4/28.
//

import UIKit

extension SettingsViewController {
    private enum Section {
        case main
    }
}

class SettingsViewController: BaseViewController {

    private var dataList: [SettingsItem] = [
        SettingsItem(.appearanceMode, dataType: .selectVal(value: UserSettings.appearanceMode.description)),
        SettingsItem(.autoOpenBook, dataType: .switchVal(isOn: UserSettings.autoOpenBook)),
        SettingsItem(.transitionStyle, dataType: .selectVal(value: UserSettings.transitionStyle.description))
    ]
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.allowsSelection = false
        tableView.backgroundColor = .systemGroupedBackground
        tableView.estimatedRowHeight = 0
        tableView.rowHeight = 55
        SettingsItem.allCasesWidgets.forEach({ tableView.register($0, forCellReuseIdentifier: $0.reuseIdentifier) })
        return tableView
    }()
    
    private var dataSource: UITableViewDiffableDataSource<Section, SettingsItem>!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
        setupDataSource()
        applySnapshot()
    }
    
    private func setupUI() {
        title = "设置"
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, SettingsItem>(tableView: tableView) { [unowned self] tableView, indexPath, model in
            let cell = tableView.dequeueReusableCell(withIdentifier: model.widget.reuseIdentifier, for: indexPath) as! SettingsCellProtocol
            cell.config(with: model)
            handleCellEvent(cell: cell, indexPath: indexPath)
            return cell
        }
        dataSource.defaultRowAnimation = .none
    }
    
    private func handleCellEvent(cell: SettingsCellProtocol, indexPath: IndexPath) {
        cell.onEvent = { [unowned self, unowned cell] event in
            switch dataList[indexPath.row].itemType {
            case .appearanceMode:
                handleAppearanceModeEvent(cell: cell, indexPath: indexPath, event: event)
            case .autoOpenBook:
                handleAutoOpenBookEvent(cell: cell, indexPath: indexPath, event: event)
            case .transitionStyle:
                handleTransitionStyleEvent(cell: cell, indexPath: indexPath, event: event)
            }
        }
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, SettingsItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(dataList, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
}

// MARK: - Business
extension SettingsViewController {
    
    private func handleAppearanceModeEvent(cell: SettingsCellProtocol, indexPath: IndexPath, event: SettingsCellEventType) {
        let alert = UIAlertController(title: "请选择观看模式", message: "当前模式为：\(UserSettings.appearanceMode)", preferredStyle: .actionSheet)
        UserSettings.AppearanceMode.allCases.forEach { mode in
            let action = UIAlertAction(title: mode.description, style: .default) { (_) in
                UserSettings.appearanceMode = mode
                self.dataList[indexPath.row].dataType = .selectVal(value: mode.description)
                cell.config(with: self.dataList[indexPath.row])
            }
            alert.addAction(action)
        }
        
        let cancel = UIAlertAction(title: "取消", style: .cancel)
        alert.addAction(cancel)
    
        present(alert, animated: true, completion: nil)
    }
    
    private func handleAutoOpenBookEvent(cell: SettingsCellProtocol, indexPath: IndexPath, event: SettingsCellEventType) {
        if case .switchClick(let isOn) = event {
            self.dataList[indexPath.row].dataType = .switchVal(isOn: isOn)
            UserSettings.autoOpenBook = isOn
        }
    }
    
    private func handleTransitionStyleEvent(cell: SettingsCellProtocol, indexPath: IndexPath, event: SettingsCellEventType) {
        let alert = UIAlertController(title: "请选择翻页效果", message: "当前翻页效果为：\(UserSettings.transitionStyle)", preferredStyle: .actionSheet)
        UserSettings.TransitionStyle.allCases.forEach { style in
            let action = UIAlertAction(title: style.description, style: .default) { (_) in
                UserSettings.transitionStyle = style
                self.dataList[indexPath.row].dataType = .selectVal(value: style.description)
                cell.config(with: self.dataList[indexPath.row])
            }
            alert.addAction(action)
        }
        
        let cancel = UIAlertAction(title: "取消", style: .cancel)
        alert.addAction(cancel)
    
        present(alert, animated: true, completion: nil)
    }
    
}
