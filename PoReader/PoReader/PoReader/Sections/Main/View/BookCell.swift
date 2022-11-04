//
//  BookCell.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/19.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit
import SnapKit

class BookCell: UICollectionViewCell {
    
    static let identifier = "BookCell"
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .dynamicColor(light: UIColor(red: 0, green: 0.48, blue: 0.8, alpha: 1),
                                                  dark: UIColor(red: 0.04, green: 0.52, blue: 0.8, alpha: 1))
        return imageView
    }()
    
    private lazy var typeIndicator: UILabel = {
        let indicator = UILabel()
        indicator.text = "TXT"
        indicator.textColor = .dynamicColor(light: UIColor(red: 0, green: 0.48, blue: 0.8, alpha: 1),
                                            dark: UIColor(red: 0.04, green: 0.52, blue: 0.8, alpha: 1))
        indicator.font = .systemFont(ofSize: 15)
        indicator.textAlignment = .center
        indicator.backgroundColor = .white
        return indicator
    }()
    
    private lazy var selectView: UIImageView = {
        let imageView = UIImageView()
        imageView.isHidden = true
        imageView.image = UIImage(named: "choose_uncheck")
        return imageView
    }()

    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .dynamicColor(light: .black,
                                        dark: UIColor(white: 0.8, alpha: 1))
        return label
    }()
    
    private lazy var processLabel: UILabel = {
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
    
    
    var model: BookModel? {
        didSet {
            guard let model = model else { return }
            titleLabel.text = model.name
            if model.progress == 0 {
                processLabel.text = "未读"
            } else {
                processLabel.text = String(format: "%.1f%%", model.progress * 100)
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
