//
//  SettingsSwitchCell.swift
//  PoReader
//
//  Created by zhongshan on 2025/4/28.
//

import UIKit

class SettingsSwitchCell: UITableViewCell, SettingsCellProtocol {

    var onEvent: ((SettingsCellEventType) -> Void)?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        return label
    }()
    
    private lazy var switchView: UISwitch = {
        let switchView = UISwitch()
        switchView.addTarget(self, action: #selector(handleSwitchViewChange(_:)), for: .valueChanged)
        return switchView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(switchView)
        switchView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-15)
        }
        
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(15)
            make.trailing.lessThanOrEqualTo(switchView.snp.leading).offset(-5)
        }
    }
    
    func config(with data: SettingsItem) {
        titleLabel.text = data.title
        if case .switchVal(let isSelected) = data.dataType {
            switchView.isOn = isSelected
        }
    }
    
    @objc
    private func handleSwitchViewChange(_ sender: UISwitch) {
        onEvent?(.switchClick(isOn: sender.isOn))
    }

}
