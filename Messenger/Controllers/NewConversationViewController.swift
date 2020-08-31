//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by Aarish  Brohi on 8/3/20.
//  Copyright © 2020 Aarish Brohi. All rights reserved.
//

import UIKit
import JGProgressHUD

class NewConversationViewController: UIViewController {
    
    public var completion: ( (SearchResult) -> (Void))?
    
    private let spinner = JGProgressHUD(style: .dark)

    //need to filter out current user
    private var users = [[String: String]]()
    private var results = [SearchResult]()
    private var hasFetched = false
    
    private let searchBar : UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for Users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(NewConversationCell.self, forCellReuseIdentifier: NewConversationCell.identifier)
        return table
    }()
    
    private let noResultsLabel : UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.text = "No results"
        label.textAlignment = .center
        label.textColor = .green
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(noResultsLabel)
        view.addSubview(tableView)
        tableView.delegate  = self
        tableView.dataSource = self
        view.backgroundColor = .white
        searchBar.delegate = self
        //put bar in navigation bar
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self,
                                                            action: #selector(dismissSelf))
    
        //invoke keyboard as soon as button is called
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width/4, y: (view.height - 200) / 2, width: view.width/2, height: 200)
    }
    
    @objc private func dismissSelf(){
        dismiss(animated: true, completion: nil)
    }

}

extension NewConversationViewController: UISearchBarDelegate{
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        searchBar.resignFirstResponder()
        
        //remove results array when canceled
        results.removeAll()
        spinner.show(in: view)
        searchUsers(query: text)
    }
    
    func searchUsers(query: String){
        //check if array has firebase reuslts
        if hasFetched{
            //if it does -> filter
            filterUser(with: query)
        }
        else{
            //if it doesnt, get it then filter
            DatabaseManager.shared.getAllUsers(completion: {[weak self] result in
                switch result {
                case .success(let userCollection):
                    self?.hasFetched = true
                    self?.users = userCollection
                    self?.filterUser(with: query)
                case .failure(let error):
                    print("Failed to get Users in New Conversation: \(error)")
                }
            })
        }
        
        //then update UI -> either shows or doesnt results for label
    }
    
    func filterUser(with term: String){
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String, hasFetched else{
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        self.spinner.dismiss()
        let results : [SearchResult] = self.users.filter({
            
            //not search up current user
            guard let email = $0["email"],email != safeEmail else{
                return false
            }
            
            guard let name = $0["name"]?.lowercased() else{
                return false
            }
            //if name has charterters of prefix in whole name
            return name.hasPrefix(term.lowercased())
        }).compactMap({
            guard let email = $0["email"], let name = $0["name"] else{
                return nil
            }
            
            return SearchResult(name: name, email: email)
        })
        
        self.results = results
        
        updateUI()
    }
    
    func updateUI(){
        if results.isEmpty{
            self.noResultsLabel.isHidden = false
            self.tableView.isHidden = true
        }
        else{
            self.noResultsLabel.isHidden = true
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
    
}

extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier, for: indexPath) as! NewConversationCell
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        //start conversation
        let targerUserData = results[indexPath.row]
        
        dismiss(animated: true, completion: { [weak self] in
            self?.completion?(targerUserData)
        })
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}

struct SearchResult {
    let name: String
    let email : String
}
