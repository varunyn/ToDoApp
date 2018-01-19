//
//  ItemViewController.swift
//  ToDoApp
//
//  Created by Varun Yadav on 1/17/18.
//  Copyright © 2018 Varun Yadav. All rights reserved.
//

import UIKit
import RealmSwift
import TwicketSegmentedControl
import SwiftReorder

class ItemViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, TwicketSegmentedControlDelegate, TableViewReorderDelegate {
    
    
    func didSelect(_ segmentIndex: Int) {
        if segmentIndex == 1 {
            todoItems = selectedCategory?.items.filter("done == true").sorted(byKeyPath: "order", ascending: true)
            tableView.reloadData()
            
        } else if segmentIndex == 0 {
            todoItems = selectedCategory?.items.sorted(byKeyPath: "order", ascending: true)
            tableView.reloadData()
        } else {
            todoItems = selectedCategory?.items.filter("done == false").sorted(byKeyPath: "order", ascending: true)
            tableView.reloadData()
        }
    }
    
    var segmentValue = 0
    
    var delegate: UpdateCompletedTasksNumber?
    
    private var completedTasksCount = 0
    //    private var pendingTasksCount = 0
    var totalTasksCount = 0
    
    var isModified : Bool?
    
    let myView = UIView(frame: CGRect(x: 0, y: 0, width:50, height: 50))
    
    @IBOutlet weak var segmentControl: TwicketSegmentedControl!
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var addButton: UIButton!

    var todoItems: Results<Item>?
    let realm = try! Realm()
    
    var selectedCategory: Category?
    
    func loadItems(){
        todoItems = selectedCategory?.items.sorted(byKeyPath: "order", ascending: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addButton.clipsToBounds = true
        addButton.layer.cornerRadius = 20
        addButton.layer.maskedCorners = [.layerMinXMinYCorner]
        
        navigationItem.title = String(describing: (selectedCategory?.name)!)
        
        loadItems()
        
        let titles = ["All", "Completed", "Pending"]
        segmentControl.setSegmentItems(titles)
        segmentControl.delegate = self
        
        segmentControl.sliderBackgroundColor  = UIColor(hue: 0.55, saturation: 0.44, brightness: 1, alpha: 1.0)
        self.view.addSubview(myView)
        
        tableView.reorder.delegate = self as? TableViewReorderDelegate
        
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if isModified != nil {
            let count = completedTasksCount
            let TotalCount = totalTasksCount
            delegate?.updateValue(count: count, TotalCount: TotalCount)
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
       
        self.tableView.reloadData()
        isModified = true
        totalTasksCount = todoItems!.count
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return todoItems?.count ?? 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let spacer = tableView.reorder.spacerCell(for: indexPath) {
            return spacer
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "ToDoItemCell", for: indexPath) as! CustomTableViewCell
        
        if let item = todoItems?[indexPath.row] {
//            cell.taskLabel?.text = item.title
            if item.done == true {
                cell.doneButton.setImage(UIImage(named : "Cancel_button"), for: .normal)
                cell.doneButton.addTarget(self, action: #selector(handleTap(button:)), for: .touchUpInside)
                cell.taskLabel.textColor = UIColor.lightGray
                
                let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: (todoItems?[indexPath.row].title)!)
                attributeString.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
                
                cell.taskLabel.attributedText = attributeString
                
            } else {
                cell.doneButton.setImage(UIImage(named : "none"), for: .normal)
                cell.doneButton.addTarget(self, action: #selector(handleTap(button:)), for: .touchUpInside)
                cell.taskLabel.textColor = UIColor(hue: 1, saturation: 0, brightness: 0.26, alpha: 1.0)
                let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: (todoItems?[indexPath.row].title)!)
                attributeString.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
                
                cell.taskLabel.attributedText = attributeString
            }
            
        } else {
            cell.textLabel?.text = "No Items Added"
        }
        
        return cell
    }
 
    func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        try! realm.write {
            let sourceObject = todoItems![sourceIndexPath.row]
            let destinationObject = todoItems![destinationIndexPath.row]
            
            let destinationObjectOrder = destinationObject.order
            
            if sourceIndexPath.row < destinationIndexPath.row {
                
                for index in sourceIndexPath.row...destinationIndexPath.row {
                    let object = todoItems![index]
                    object.order -= 1
                }
            } else {
                
                for index in (destinationIndexPath.row..<sourceIndexPath.row).reversed() {
                    let object = todoItems![index]
                    object.order += 1
                }
            }
            
            sourceObject.order = destinationObjectOrder
        }
        self.tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (action, view, handler) in
            if let item = self.todoItems?[indexPath.row] {
                do {
                    try self.realm.write {
                        if item.done == true {
                            self.completedTasksCount -= 1
                        }
                        self.realm.delete(item)
                    }
                }
                catch {
                    print("Error deleting data, \(error)")
                }
            }
            self.tableView.reloadData()
            self.isModified = true
            self.totalTasksCount = self.todoItems!.count
            
            print("Delete Action Tapped")
        }
        
        deleteAction.backgroundColor = .red
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        return configuration
    }

    @objc func handleTap (button: UIButton) {
        var row = 0
        realm.beginWrite()
        isModified = true
        
        if button.imageView!.image == UIImage(named:"Cancel_button") {
            button.setImage(UIImage(named:"Circle_empty"), for: .normal )
            if let cell = button.superview!.superview as? CustomTableViewCell {
                row = tableView.indexPath(for: cell)!.row
                cell.taskLabel.textColor = UIColor(hue: 1, saturation: 0, brightness: 0.26, alpha: 1.0)
                
                let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: (todoItems?[row].title)!)
                attributeString.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
                
                cell.taskLabel.attributedText = attributeString
                
            }

            todoItems?[row].done = false
            //            pendingTasksCount += 1
            completedTasksCount -= 1
            try! realm.commitWrite()
            
            self.tableView.reloadData()
        } else {
            button.setImage(UIImage(named:"Cancel_button"), for: .normal )
            if let cell = button.superview!.superview as? CustomTableViewCell {
                row = tableView.indexPath(for: cell)!.row
                let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: (todoItems?[row].title)!)
                attributeString.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
                
                cell.taskLabel.attributedText = attributeString
                
                cell.taskLabel.textColor = UIColor.lightGray
            }
            
            todoItems?[row].done = true
            completedTasksCount += 1
            //            pendingTasksCount -= 1
            
            try! realm.commitWrite()
              self.tableView.reloadData()
        }
    }
    
    // MARK - Add New Items
    
    @IBAction func addButtonPressed(_ sender: Any) {
        let destinationVC = storyboard?.instantiateViewController(withIdentifier: "AddTask") as! AddTaskViewController
        destinationVC.currentCategory = self.selectedCategory
        self.navigationController?.pushViewController(destinationVC, animated: true)
    }
    
    deinit {
//        print("deinit")
    }    
}

