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
        categories = realm.objects(Category.self)
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
        
        print(initialTotalTasks)
        
        if let cell = CatergoryCollection.cellForItem(at: currentCellIndex) as? CollectionViewCell {
            cell.tasksCountLabel.text = String(initialTotalTasks) + " " + "tasks"
        }
        
        completedTaskLabel.text = String(initialCompletedTasks)
        
        
        
        
//        let cell = CollectionViewCell()
//        cell.tasksCountLabel.text = String(initialTotalTasks)
    }
}

protocol UpdateCompletedTasksNumber : class {
    func updateValue(count:Int, TotalCount: Int) -> ()
}



