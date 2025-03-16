//
//  SwitchCell.swift
//  NavigationBar
//
//  Created by 黄中山 on 2020/3/31.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit

class SwitchCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var switchButton: UISwitch!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction
    private func switchChange(_ sender: UISwitch) {
        
    }
    
}
