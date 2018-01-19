//
//  CategoryViewController.swift
//  ToDoApp
//
//  Created by Varun Yadav on 1/16/18.
//  Copyright © 2018 Varun Yadav. All rights reserved.
//

import UIKit
import RealmSwift

class CategoryViewController: UIViewController,UICollectionViewDelegate, UICollectionViewDataSource {
   
    let realm = try! Realm()
    
    private var currentCellIndex : IndexPath!

    var categories: Results<Category>?
    @IBOutlet weak var CatergoryCollection: UICollectionView!
    
    @IBOutlet weak var DateLabel: UILabel!

    @IBOutlet weak var addButton: UIButton!
    
    @IBOutlet weak var totalTaskLabel: UILabel!
    
    @IBOutlet weak var completedTaskLabel: UILabel!
    
    
    private var initialCompletedTasks = 0
     private var initialTotalTasks = 0
    
    
    @IBAction func addCategoryButton(_ sender: Any) {
        
        let alert = UIAlertController(title: "Add new category",message : "",preferredStyle: .alert)
        
        let cancel = UIAlertAction(title: "Cancel",style: .cancel) { (action) in
        }
        
        alert.addTextField { (field) in
            field.placeholder = "Add new category"
        }
        
        let action = UIAlertAction(title: "Add",style: .default) { (action)  in
            let newCategory = Category()
            newCategory.name  = alert.textFields![0].text!
            self.save(category: newCategory)
        }
        alert.addAction(action)
        
        alert.addAction(cancel)
        present(alert, animated: true, completion: nil)
        
    }
    
    func save(category:Category){
        do {
            try realm.write {
                realm.add(category)
            }
        } catch {
                print("Error saving category \(error)" )
            }
        self.CatergoryCollection.reloadData()
        }
    
    func loadCategories(){
        categories = realm.objects(Category.self).sorted(byKeyPath: "order", ascending: true)
        CatergoryCollection.reloadData()
    }
    
    func CountItem() {
        var count = 0
        var completedTaskCount = 0
        
        if categories != nil {
            for i in categories! {
                count +=  i.items.count
                for item in i.items {
                    if item.done == true {
                        completedTaskCount += 1
                    }
                }
            }
            initialCompletedTasks = completedTaskCount
            totalTaskLabel.text = String(count)
            completedTaskLabel.text = String(completedTaskCount)
        } else {
            totalTaskLabel.text = String(0)
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let month = Calendar.current.component(.month, from: today)
        let date = Calendar.current.component(.day, from: today)
        DateLabel.text = "\(Calendar.current.weekdaySymbols[weekday-1])," + " " + "\(Calendar.current.shortMonthSymbols[month-1]) \(date)"
        
        addButton.clipsToBounds = true
        addButton.layer.cornerRadius = 20
        addButton.layer.maskedCorners = [.layerMinXMinYCorner]
        print("viewdidload 111 ")
        loadCategories()

        CountItem()
    
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongGesture(gesture:)))
        CatergoryCollection.addGestureRecognizer(longPressGesture)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
       var totaltaskscount = 0
        
        if categories != nil {
            for i in categories! {
                totaltaskscount +=  i.items.count
            }
        }
        totalTaskLabel.text = String(totaltaskscount)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories?.count ?? 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CollectionViewCell
        
        if indexPath.row % 2 != 0 {
            cell.rightBorderLine.isHidden = true
        }
        
        cell.CategoryLabel?.text = categories?[indexPath.row].name ?? "No Categories Added"
        
        if categories?.count != 0 {
            cell.tasksCountLabel?.text = String(describing: categories![indexPath.row].items.count) + " " + "tasks"
            
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        try! realm.write {
            let sourceObject = categories?[sourceIndexPath.row]
            let destinationObject = categories?[destinationIndexPath.row]
            
            let destinationObjectOrder = destinationObject?.order
            
            if sourceIndexPath.row < destinationIndexPath.row {
                
                for index in sourceIndexPath.row...destinationIndexPath.row {
                    let object = categories?[index]
                    object?.order -= 1
                }
            } else {
                
                for index in (destinationIndexPath.row..<sourceIndexPath.row).reversed() {
                    let object = categories?[index]
                    object?.order += 1
                }
            }
            sourceObject?.order = destinationObjectOrder!
        }
        
        self.CatergoryCollection.reloadData()
    }
    
   
    
    fileprivate var longPressGesture: UILongPressGestureRecognizer!
    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        switch(gesture.state) {
        case .began:
            guard let selectedIndexPath = CatergoryCollection.indexPathForItem(at: gesture.location(in: CatergoryCollection)) else {
                break
            }
            CatergoryCollection.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            CatergoryCollection.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))

        case .ended:
            CatergoryCollection.endInteractiveMovement()

        default:
            CatergoryCollection.cancelInteractiveMovement()
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        currentCellIndex = indexPath
        let viewController = storyboard?.instantiateViewController(withIdentifier: "Identifier") as! ItemViewController
        viewController.selectedCategory = categories?[indexPath.row]
        viewController.delegate = self
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

extension CategoryViewController : UpdateCompletedTasksNumber {
    func updateValue(count: Int, TotalCount: Int) {
        
        initialCompletedTasks += count
        initialTotalTasks = TotalCount
        if let cell = CatergoryCollection.cellForItem(at: currentCellIndex) as? CollectionViewCell {
        cell.tasksCountLabel.text = String(initialTotalTasks) + " " + "tasks"
        }
        completedTaskLabel.text = String(initialCompletedTasks)
    }
}

protocol UpdateCompletedTasksNumber : class {
    func updateValue(count:Int, TotalCount: Int) -> ()
}




