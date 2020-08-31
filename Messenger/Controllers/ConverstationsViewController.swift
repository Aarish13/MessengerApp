//
//  ViewController.swift
//  Messenger
//
//  Created by Aarish  Brohi on 8/3/20.
//  Copyright © 2020 Aarish Brohi. All rights reserved.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

struct Conversation {
    let id : String
    let name : String
    let otherUserEmail : String
    let latestMesseage : LatestMessage
}

struct LatestMessage {
    let date : String
    let text : String
    let isRead : Bool
}

class ConverstationsViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()
    
    private var loginObserver : NSObjectProtocol?
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.identifier)
        return table
    }()
    
    private let noConversationLabel: UILabel = {
       let label = UILabel()
        label.text = "No Conversation"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                                            target: self, action: #selector(didTapComposeButton))
        view.addSubview(tableView)
        view.addSubview(noConversationLabel)
        setupTableView()
        fetchConversations()
        startListeningForConversations()
        
        //whenever notifivation gets fired, block gets fired bc when first open up app when loggin on
        //with user who had account before, messages wouldnt show till reuploading app
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification , object: nil, queue: .main, using: {[weak self] _ in
            guard let strongSelf = self else{
                return
            }
            //when user logs in, call this
            strongSelf.startListeningForConversations()
        })
        
    }
    private func startListeningForConversations(){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        //once user gets messages first time, it stays, no need for nofication observer now
        if let observer = loginObserver{
            NotificationCenter.default.removeObserver(observer)
        }
        print("start convo fetch")
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConversations(for: safeEmail, completion: { [weak self] result in
            switch result{
            case .success(let conversations):
                print("successful gets convo models")
                guard !conversations.isEmpty else{
                    return
                }
                self?.conversations = conversations
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
                
            case .failure(let error):
                print("failed to get conversations: \(error)")
            }
            
        })
    }
    
    
    @objc private func didTapComposeButton(){
        let vc = NewConversationViewController()
        vc.completion = { [weak self] result in
            //result has emai; property
            //once selected user need to checki f convo exist, if does want to open it
            //check datasbe manger if exist covno
            guard let strongSelf = self  else{
                return
            }
            
            let currentConversations = strongSelf.conversations
            if let targetConversation = currentConversations.first(where: {
                $0.otherUserEmail == DatabaseManager.safeEmail(emailAddress: result.email)
            }){
                let vc = ChatViewController(with: targetConversation.otherUserEmail, id: targetConversation.id)
                vc.isNewConversation = false
                vc.title = targetConversation.name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
            else{
                strongSelf.createNewConversation(result: result)
            }
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    
    
    private func createNewConversation(result : SearchResult){
        let name = result.name
        let email = DatabaseManager.safeEmail(emailAddress: result.email)
        
        //check in Database if conversations with two users exsit
        //if it does resuse convo id
        //else create new convo id
        
        DatabaseManager.shared.conversationExist(with: email, completion: {[weak self] result in
            guard let strongSelf = self else{
                return
            }
            switch result {
            case .success(let conversationId):
                let vc = ChatViewController(with: email, id: conversationId)
                vc.isNewConversation = false
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                let vc = ChatViewController(with: email, id: nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        })
        
        
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool){
        super.viewDidAppear(animated)
        validateAuth()
    }
    
    private func validateAuth(){
        if FirebaseAuth.Auth.auth().currentUser == nil{
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        }
    }
    
    private func setupTableView(){
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func fetchConversations(){
        tableView.isHidden = false
    }
    
}


extension ConverstationsViewController : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier,
                                                 for: indexPath) as! ConversationTableViewCell
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConversations(model)
        
    }
    
    //search user who has already had a convo with
    func openConversations(_ model: Conversation){
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    //called when swipe row away, handle delete action of above function
    //first get of row
    //update model after deleteing row, if not would crash as table view section of one
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            //begin delete
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            DatabaseManager.shared.deleteConversation(conversationId: conversationId, completion: {[weak self] success in
                if success{
                    self?.conversations.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .left)
                }
            })
            
            tableView.endUpdates()
        }
    }
    
}
