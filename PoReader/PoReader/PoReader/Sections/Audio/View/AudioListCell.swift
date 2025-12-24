import UIKit

class AudioListCell: UICollectionViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .dynamicColor(light: .black,
                                        dark: UIColor(white: 0.8, alpha: 1))
        return label
    }()
    
    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .dynamicColor(light: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6),
                                        dark: UIColor(white: 0.7, alpha: 1))
        return label
    }()
    
    private let dot: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0, green: 0.8, blue: 0, alpha: 1)
        view.layer.cornerRadius = 4
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(15)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        progressLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        progressLabel.setContentHuggingPriority(.required, for: .horizontal)
        contentView.addSubview(progressLabel)
        progressLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(20)
            make.trailing.equalToSuperview().offset(-15)
        }
        
        contentView.addSubview(dot)
        dot.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-3.5)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(8)
        }
    }
    
    func config(with data: AudioModel, isSelected: Bool) {
        titleLabel.text = data.name
        
        if data.progress == 0 {
            progressLabel.text = "未听"
        } else {
            progressLabel.text = String(format: "%.1f%%", data.progress * 100)
        }
        dot.isHidden = !isSelected
    }
    
}
