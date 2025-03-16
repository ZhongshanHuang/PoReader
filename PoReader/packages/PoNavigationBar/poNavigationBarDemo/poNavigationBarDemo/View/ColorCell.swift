//
//  ColorCell.swift
//  NavigationBar
//
//  Created by 黄中山 on 2020/3/31.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

class ColorCell: UITableViewCell {
    
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
