//
//  SearchTableviewController.swift
//  find address
//
//  Created by Andriy GORDIYCHUK on 1/27/19.
//  Copyright © 2019 Volodymyr KOZHEMIAKIN. All rights reserved.
//

import Foundation
import UIKit
import MapKit

final class SearchTableViewController: UITableViewController, UISearchBarDelegate {
    
    weak var delegate:ViewController?
    var items:[MKMapItem] = [] {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MyCell")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyCell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row].name
        return cell
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        //ignoring user
        //Activity indicator
        (parent as? UISearchController)?.isActive = true
        
        // create search request
        let searchRequest = MKLocalSearchRequest()
        searchRequest.naturalLanguageQuery = searchBar.text //  searchBar.text on FirstViewController !!!
        print(searchBar.text ?? "")
        
        let activeSearch = MKLocalSearch(request: searchRequest)
        activeSearch.start {[weak self] (response, error) in
            guard let s = self else {return}
            if let e = error {
                ErrorReporter.showError(e.localizedDescription, from: s)
            }
            if let res = response {
                // remove annotations
                s.items = res.mapItems
            } else {
                ErrorReporter.showError("No response", from: s)
            }
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        items = []
    }
    
    
}
