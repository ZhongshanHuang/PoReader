import UIKit

class SettingsSelectCell: UITableViewCell, SettingsCellProtocol {

    var onEvent: ((SettingsCellEventType) -> Void)?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .pingfang(ofSize: 17, weight: .regular)
        label.textColor = .label
        return label
    }()
    
    private let indicatorView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = UIColor(white: 0, alpha: 0.6)
        return imageView
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .pingfang(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(indicatorView)
        indicatorView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-15)
        }
        
        contentView.addSubview(valueLabel)
        valueLabel.setContentCompressionResistancePriority(.defaultLow + 1, for: .horizontal)
        valueLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(indicatorView.snp.leading).offset(-5)
        }
        
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(15)
            make.trailing.lessThanOrEqualTo(valueLabel.snp.leading).offset(-15)
        }
        
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(handleButtonClick(_:)), for: .touchUpInside)
        contentView.addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func config(with data: SettingsItem) {
        titleLabel.text = data.title
        if case .selectVal(let value) = data.dataType {
            valueLabel.text = value
        }
    }
    
    @objc
    private func handleButtonClick(_ sender: UIButton) {
        onEvent?(.selectClick)
    }

}
