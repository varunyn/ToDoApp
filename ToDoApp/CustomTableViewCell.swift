//
//  CustomTableViewCell.swift
//  ToDoApp
//
//  Created by Varun Yadav on 1/17/18.
//  Copyright © 2018 Varun Yadav. All rights reserved.
//

import UIKit

class CustomTableViewCell: UITableViewCell {

    
    @IBOutlet weak var doneButton: UIButton!
    
    
    
    @IBOutlet weak var taskLabel: UILabel!
    
    @IBAction func cancelButton(_ sender: Any) {
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
