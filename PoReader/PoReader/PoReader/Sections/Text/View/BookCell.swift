import UIKit
import SnapKit

class BookCell: UICollectionViewCell {
    
    var animationView: UIView {
        imageView
    }
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .dynamicColor(light: UIColor(red: 0, green: 0.48, blue: 0.8, alpha: 1),
                                                  dark: UIColor(red: 0.04, green: 0.52, blue: 0.8, alpha: 1))
        return imageView
    }()
    
    private let typeIndicator: UILabel = {
        let indicator = UILabel()
        indicator.text = "TXT"
        indicator.textColor = .dynamicColor(light: UIColor(red: 0, green: 0.48, blue: 0.8, alpha: 1),
                                            dark: UIColor(red: 0.04, green: 0.52, blue: 0.8, alpha: 1))
        indicator.font = .systemFont(ofSize: 15)
        indicator.textAlignment = .center
        indicator.backgroundColor = .white
        return indicator
    }()
    
    private let selectView: UIImageView = {
        let imageView = UIImageView()
        imageView.isHidden = true
        imageView.image = UIImage(named: "choose_uncheck")
        return imageView
    }()

    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .dynamicColor(light: .black,
                                        dark: UIColor(white: 0.8, alpha: 1))
        return label
    }()
    
    private let processLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .dynamicColor(light: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6),
                                        dark: UIColor(white: 0.7, alpha: 1))
        return label
    }()
    
    var showEditing: Bool = false {
        didSet {
            selectView.isHidden = !showEditing
        }
    }
    
    override var isSelected: Bool {
        didSet {
            if showEditing {
                let image = isSelected ? UIImage(named: "choose_check") : UIImage(named: "choose_uncheck")
                selectView.image = image
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func config(with data: BookModel) {
        titleLabel.text = data.name
        if data.progress == 0 {
            processLabel.text = "未读"
        } else {
            processLabel.text = String(format: "%.1f%%", data.progress * 100)
        }
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.top.left.right.equalToSuperview()
        }
        
        imageView.addSubview(typeIndicator)
        typeIndicator.snp.makeConstraints { (make) in
            make.left.equalToSuperview()
            make.bottom.equalToSuperview().multipliedBy(0.8)
            make.size.equalTo(CGSize(width: 60, height: 20))
        }
        
        contentView.addSubview(selectView)
        selectView.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(5)
            make.right.equalToSuperview().offset(-5)
        }
        
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.top.equalTo(imageView.snp.bottom).offset(2)
            make.left.right.equalToSuperview()
        }
        
        contentView.addSubview(processLabel)
        processLabel.snp.makeConstraints { (make) in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.left.bottom.right.equalToSuperview()
        }
    }
    
}
