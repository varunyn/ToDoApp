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
    
    @IBOutlet weak var addTask: UIButton!
    
    @IBOutlet weak var textField: UITextField!
    
    @IBAction func addTaskPressed(_ sender: Any) {
        if let currentCategory = self.currentCategory {
            if textField.text != "" {
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
            }  else {
                print("Add something")
            }
            
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addTask.layer.cornerRadius = 10
        addTask.layer.shadowRadius = 10
        addTask.layer.shadowOffset = CGSize.init(width: 0, height: 10)
        addTask.layer.shadowOpacity = 0.5
        addTask.layer.shadowColor = UIColor.red.cgColor
        
        
    }
    
    
}
