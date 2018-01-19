//
//  AddTaskViewController.swift
//  ToDoApp
//
//  Created by Varun Yadav on 1/18/18.
//  Copyright © 2018 Varun Yadav. All rights reserved.
//

import UIKit
import RealmSwift

class AddTaskViewController: UIViewController{
    
    
    var currentCategory: Category?
    
    let realm = try! Realm()
    
    
    @IBOutlet weak var textField: UITextField!
    
    @IBAction func addTaskPressed(_ sender: Any) {
        if let currentCategory = self.currentCategory {
            do {
                try self.realm.write {
                    let newItem = Item()
                    newItem.title = textField.text!
                    currentCategory.items.append(newItem)
                    
                    self.navigationController?.popViewController(animated: true)
                    
                }
            } catch {
                print("Error saving new items, \(error)")
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    
}
