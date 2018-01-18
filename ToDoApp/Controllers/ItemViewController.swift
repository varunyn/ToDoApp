//
//  ItemViewController.swift
//  ToDoApp
//
//  Created by Varun Yadav on 1/17/18.
//  Copyright © 2018 Varun Yadav. All rights reserved.
//

import UIKit
import RealmSwift

class ItemViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var segmentValue = 0
    
    var delegate: UpdateCompletedTasksNumber?
    
    private var completedTasksCount = 0
//    private var pendingTasksCount = 0
    private var totalTasksCount = 0
    
    var isModified : Bool?
    

    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var addButton: UIButton!
    
    @IBAction func segmentControl(_ sender: UISegmentedControl) {
        
        segmentValue = sender.selectedSegmentIndex

        if segmentValue == 1 {
            todoItems = selectedCategory?.items.filter("done == true").sorted(byKeyPath: "title", ascending: true)
            tableView.reloadData()
        } else if segmentValue == 0 {
            todoItems = selectedCategory?.items.sorted(byKeyPath: "title", ascending: true)
            tableView.reloadData()
        } else {
            todoItems = selectedCategory?.items.filter("done == false").sorted(byKeyPath: "title", ascending: true)
            tableView.reloadData()
        }
        
    }
    
    var todoItems: Results<Item>?
    let realm = try! Realm()
    
    var selectedCategory: Category?
    
    func loadItems(){
        todoItems = selectedCategory?.items.sorted(byKeyPath: "title", ascending: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addButton.clipsToBounds = true
        addButton.layer.cornerRadius = 20
        addButton.layer.maskedCorners = [.layerMinXMinYCorner]
        
        loadItems()
        
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if isModified != nil {
            let count = completedTasksCount
            let TotalCount = totalTasksCount
            delegate?.updateValue(count: count, TotalCount: TotalCount)
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return todoItems?.count ?? 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "ToDoItemCell", for: indexPath) as! CustomTableViewCell
        
        if let item = todoItems?[indexPath.row] {
            cell.taskLabel?.text = item.title
            
            totalTasksCount += 1
            
            if item.done == true {
                cell.doneButton.setImage(UIImage(named : "Cancel_button"), for: .normal)
                cell.doneButton.addTarget(self, action: #selector(handleTap(button:)), for: .touchUpInside)
                cell.taskLabel.textColor = UIColor.lightGray
            } else {
                cell.doneButton.setImage(UIImage(named : "Circle_empty"), for: .normal)
                cell.doneButton.addTarget(self, action: #selector(handleTap(button:)), for: .touchUpInside)
                cell.taskLabel.textColor = UIColor.blue
            }
            
        } else {
            cell.textLabel?.text = "No Items Added"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    
    
    @objc func handleTap (button: UIButton) {
        var row = 0
        realm.beginWrite()
        isModified = true
        
        if button.imageView!.image == UIImage(named:"Cancel_button") {
            button.setImage(UIImage(named:"Circle_empty"), for: .normal )
            if let cell = button.superview!.superview as? CustomTableViewCell {
                row = tableView.indexPath(for: cell)!.row
                cell.taskLabel.textColor = UIColor.blue
                
            }
            
            
            todoItems?[row].done = false
//            pendingTasksCount += 1
            completedTasksCount -= 1
            try! realm.commitWrite()
        } else {
            button.setImage(UIImage(named:"Cancel_button"), for: .normal )
            if let cell = button.superview!.superview as? CustomTableViewCell {
                row = tableView.indexPath(for: cell)!.row
                
                cell.taskLabel.textColor = UIColor.lightGray
            }
            
            todoItems?[row].done = true
            completedTasksCount += 1
//            pendingTasksCount -= 1
            
            try! realm.commitWrite()
            
        }
    }
    
    // MARK - Add New Items
    
    @IBAction func addButtonPressed(_ sender: Any) {
        var textField = UITextField()
        
        let alert = UIAlertController(title: "Add New Item", message: "", preferredStyle: .alert)
        
        let action = UIAlertAction(title: "Add Item", style: .default) { (action) in
            
            if let currentCategory = self.selectedCategory {
                do {
                    try self.realm.write {
                        let newItem = Item()
                        newItem.title = textField.text!
                        currentCategory.items.append(newItem)
                    }
                } catch {
                    print("Error saving new items, \(error)")
                }
            }
            self.tableView.reloadData()
        }
        
        alert.addTextField { (alertTextField) in
            alertTextField.placeholder = "Create new Item"
            textField = alertTextField
        }
        
        alert.addAction(action)
        present(alert,animated: true,completion: nil)
    }
    
    deinit {
        print("deinit")
    }
    
}
