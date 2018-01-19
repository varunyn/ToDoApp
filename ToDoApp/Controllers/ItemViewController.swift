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

class ItemViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, TwicketSegmentedControlDelegate {
    
    
    func didSelect(_ segmentIndex: Int) {
        if segmentIndex == 1 {
            //            segment.setImage(#imageLiteral(resourceName: "white_bg"), forSegmentAt: 1)
            todoItems = selectedCategory?.items.filter("done == true").sorted(byKeyPath: "title", ascending: true)
            tableView.reloadData()
        } else if segmentIndex == 0 {
            
//            segment.setImage(#imageLiteral(resourceName: "white_bg"), forSegmentAt: 0)
            
            todoItems = selectedCategory?.items.sorted(byKeyPath: "title", ascending: true)
            tableView.reloadData()
        } else {
            
//            segment.setImage(#imageLiteral(resourceName: "white_bg"), forSegmentAt: 2)
            todoItems = selectedCategory?.items.filter("done == false").sorted(byKeyPath: "title", ascending: true)
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
        todoItems = selectedCategory?.items.sorted(byKeyPath: "title", ascending: true)
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
                cell.doneButton.setImage(UIImage(named : "Circle_empty"), for: .normal)
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
                cell.taskLabel.textColor = UIColor(hue: 1, saturation: 0, brightness: 0.26, alpha: 1.0)
                
                let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: (todoItems?[row].title)!)
                attributeString.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 0, range: NSMakeRange(0, attributeString.length))
                
                cell.taskLabel.attributedText = attributeString
                
            }

            todoItems?[row].done = false
            //            pendingTasksCount += 1
            completedTasksCount -= 1
            try! realm.commitWrite()
        } else {
            button.setImage(UIImage(named:"Cancel_button"), for: .normal )
            if let cell = button.superview!.superview as? CustomTableViewCell {
                row = tableView.indexPath(for: cell)!.row

//                var attributes = [NSAttributedStringKey.strikethroughStyle : 2]
//
//                var str = NSMutableAttributedString.init(string: "Varun Fabulous")
//
//                var range = NSRange.init(str)
//                str.addAttributes(attributes, range: range)
                
                let attributeString: NSMutableAttributedString =  NSMutableAttributedString(string: (todoItems?[row].title)!)
                attributeString.addAttribute(NSAttributedStringKey.strikethroughStyle, value: 2, range: NSMakeRange(0, attributeString.length))
                
                cell.taskLabel.attributedText = attributeString
                
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
//        var textField = UITextField()
//
//        let alert = UIAlertController(title: "Add New Item", message: "", preferredStyle: .alert)
//
//        let action = UIAlertAction(title: "Add Item", style: .default) { (action) in
//
//            if let currentCategory = self.selectedCategory {
//                do {
//                    try self.realm.write {
//                        let newItem = Item()
//                        newItem.title = textField.text!
//                        currentCategory.items.append(newItem)
//                    }
//                } catch {
//                    print("Error saving new items, \(error)")
//                }
//            }
//            self.tableView.reloadData()
//
//
//        }
//
//        alert.addTextField { (alertTextField) in
//            alertTextField.placeholder = "Create new Item"
//            textField = alertTextField
//        }
//
//        alert.addAction(action)
//        present(alert,animated: true,completion: nil)
        
        let destinationVC = storyboard?.instantiateViewController(withIdentifier: "AddTask") as! AddTaskViewController
        
        destinationVC.currentCategory = self.selectedCategory
        
//        self.navigationController?.popToViewController(destinationVC, animated: true)

        self.navigationController?.pushViewController(destinationVC, animated: true)
        
    }
    
    deinit {
        print("deinit")
    }
    
}
