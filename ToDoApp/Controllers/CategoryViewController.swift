//
//  CategoryViewController.swift
//  ToDoApp
//
//  Created by Varun Yadav on 1/16/18.
//  Copyright © 2018 Varun Yadav. All rights reserved.
//

import UIKit
import RealmSwift
import SCLAlertView

class CategoryViewController: UIViewController,UICollectionViewDelegate, UICollectionViewDataSource {
   
    let realm = try! Realm()
    
    private var currentCellIndex : IndexPath!
    
    var footer : UICollectionReusableView!
    

    
    private var selectImages = [Int : UIImageView] ()
    private var tapGesture : UITapGestureRecognizer!
    
    
    var categories: Results<Category>?
    @IBOutlet weak var CatergoryCollection: UICollectionView!
    
    @IBOutlet weak var DateLabel: UILabel!

    @IBOutlet weak var addButton: UIButton!
    
    @IBOutlet weak var totalTaskLabel: UILabel!
    
    @IBOutlet weak var completedTaskLabel: UILabel!
    
    @IBAction func userNameEditButtonPressed(_ sender: Any) {
//        let alert = UIAlertController(title: "Info",message : "",preferredStyle: .alert)
//
//        let cancel = UIAlertAction(title: "Cancel",style: .cancel) { (action) in
//        }
//
//        alert.addTextField { (field) in
//            field.placeholder = "Insert Name"
//        }
//
//        let action = UIAlertAction(title: "Done",style: .default) { (action)  in
//            let userName: String
//            userName  = alert.textFields![0].text!
//            UserDefaults.standard.removeObject(forKey: "Key")
//            UserDefaults.standard.set(userName, forKey: "Key")
//            self.userNameLabel.text =  UserDefaults.standard.string(forKey: "Key")
//        }
//        alert.addAction(action)
//
//        alert.addAction(cancel)
//        present(alert, animated: true, completion: nil)
//
        
        let alertView = SCLAlertView()
        
        let txt = alertView.addTextField("Enter your name")
        alertView.addButton("Change Name") {
            UserDefaults.standard.removeObject(forKey: "Key")
            UserDefaults.standard.set(txt.text, forKey: "Key")
            self.userNameLabel.text =  UserDefaults.standard.string(forKey: "Key")
        }
       
        alertView.showInfo("Info", subTitle: "Please add the name below in text field")
        
    }
    
    @IBOutlet weak var userNameLabel: UILabel!

    private var initialCompletedTasks = 0
    private var initialTotalTasks = 0
    var panGesture : UIPanGestureRecognizer!

    
    @IBAction func addCategoryButton(_ sender: Any) {
        
//        let alert = UIAlertController(title: "Add new category",message : "",preferredStyle: .alert)
//
//        let cancel = UIAlertAction(title: "Cancel",style: .cancel) { (action) in
//        }
//
//        alert.addTextField { (field) in
//            field.placeholder = "Add new category"
//        }
//
//        let action = UIAlertAction(title: "Add",style: .default) { (action)  in
//            let newCategory = Category()
//            newCategory.name  = alert.textFields![0].text!
//            self.save(category: newCategory)
//        }
//        alert.addAction(action)
//
//        alert.addAction(cancel)
//        present(alert, animated: true, completion: nil)
//
        
        let appearance = SCLAlertView.SCLAppearance(
            showCircularIcon: true
        )
        let alertView1 = SCLAlertView(appearance: appearance)

        
        let txt = alertView1.addTextField("Enter Category")
        alertView1.addButton("Add Category") {
            let newCategory = Category()
                        newCategory.name  = txt.text!
                        self.save(category: newCategory)
        }
         let alertViewIcon = UIImage(named: "category_icon")
        alertView1.showInfo("Category", subTitle: "Please add the name of the category to add", circleIconImage: alertViewIcon)
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
        
        CatergoryCollection.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "footer")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(handleEdit))
        
        

        self.userNameLabel.text =  UserDefaults.standard.string(forKey: "Key")
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
//        CatergoryCollection.addGestureRecognizer(panGesture)
        
        if let layout = CatergoryCollection.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.footerReferenceSize = CGSize(width: 0, height: 50)
            layout.sectionFootersPinToVisibleBounds = true
            

        }
        
        
    }

    
    @objc func handleEdit () {
        navigationItem.title = "Select Items"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(handleCancel))
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barTintColor = UIColor(red: 0.8471, green: 0.3804, blue: 0.3725, alpha: 1.0)
        
        addButton.isHidden = true
        footer.isHidden = false
        
        CatergoryCollection.allowsSelection = false
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSelect))
        CatergoryCollection.addGestureRecognizer(tapGesture)
        
    }
    
    @objc func handleSelect(gesture: UITapGestureRecognizer) {
        
        guard let indexPathSelected = CatergoryCollection.indexPathForItem(at: gesture.location(in: CatergoryCollection)) else {return}
        if let cell = CatergoryCollection.cellForItem(at: indexPathSelected) as? CollectionViewCell {
            if cell.imageIncluded == false {
                cell.imageIncluded = true
                let selectImageView = UIImageView(image: UIImage(named:"select"))
                selectImageView.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(selectImageView)
                selectImages[indexPathSelected.row] = selectImageView
                selectImageView.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -10).isActive = true
                selectImageView.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10).isActive = true
                selectImageView.widthAnchor.constraint(equalToConstant: 30).isActive = true
                selectImageView.heightAnchor.constraint(equalToConstant: 30).isActive = true
            } else {
                cell.imageIncluded = false
                selectImages[indexPathSelected.row]?.removeFromSuperview()
                let _ = selectImages.removeValue(forKey: indexPathSelected.row)
                
            }

            
            
        }
        
        
        
    }
    
    @objc func handleCancel() {
        navigationItem.title = ""
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(handleEdit))
        CatergoryCollection.allowsSelection = true
        CatergoryCollection.removeGestureRecognizer(tapGesture)
        footer.isHidden = true
        navigationController?.navigationBar.barTintColor = .white
        selectImages.forEach { (element) in
            element.value.removeFromSuperview()
        }
        selectImages.removeAll()
        addButton.isHidden = false

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
        
//        self.CatergoryCollection.reloadData()
    }
    
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionElementKindSectionFooter {
            footer = CatergoryCollection.dequeueReusableSupplementaryView(ofKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "footer", for: indexPath)
            footer.backgroundColor = UIColor(red: 0.8471, green: 0.3804, blue: 0.3725, alpha: 1.0)
            footer.isHidden = true
            return footer
           
        } else {
            return UICollectionReusableView()
        }
        
    }
   
    
    fileprivate var longPressGesture: UILongPressGestureRecognizer!
    


    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
        
        
        guard let selectedIndexPath = CatergoryCollection.indexPathForItem(at: gesture.location(in: CatergoryCollection)) else {
            return
        }
        
        
        switch(gesture.state) {
        case .began:
            
            
            
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




