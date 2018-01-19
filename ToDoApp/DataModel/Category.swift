//
//  Category.swift
//  ToDoApp
//
//  Created by Varun Yadav on 1/16/18.
//  Copyright © 2018 Varun Yadav. All rights reserved.
//

import Foundation
import RealmSwift

class Category: Object {
    @objc dynamic var name: String = ""
    let items = List<Item>()
    let array = Array<Int>()
    
    @objc dynamic var order = 0 
}
