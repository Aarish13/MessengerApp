//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Aarish  Brohi on 8/4/20.
//  Copyright © 2020 Aarish Brohi. All rights reserved.
//

import Foundation
import FirebaseDatabase
import MessageKit


//no sql database json
final class DatabaseManager{
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    
    //storage uses safeEmail format
    static func safeEmail(emailAddress: String) -> String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }

}

extension DatabaseManager{
    //generic function tot pass in any child path to return in fetch of data
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void){
        database.child(path).observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}




// Mark: - Account Management
//is an insert query
extension DatabaseManager{
    //not to have repetitive emails, if true cannot create
    public func userExists(with email:String, completion: @escaping((Bool)-> Void)){
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? [String: Any] != nil else{
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    //completion upload image
    //make root entry
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void){
        /// Insert new user to database
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
            ], withCompletionBlock: {error, _ in
                guard error == nil else{
                    print("Failed to write to database")
                    completion(false)
                    return
                }
                
                
                self.database.child("users").observeSingleEvent(of : .value, with: {snapshot in
                    if var usersCollection = snapshot.value as? [[String:String]]{
                        //append to user dictionary
                        let fullName = user.firstName + " " + user.lastName
                        let newElement = [
                            "name" : fullName,
                            "email" : user.safeEmail
                        ]
                            
                        usersCollection.append(newElement)
                        self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                            guard error == nil else{
                                completion(false)
                                return
                            }
                            completion(true)
                        })
                    }
                    else{
                        //create that array
                        let newCollection : [[String:String]] = [
                            [
                                "name" : user.firstName + " " + user.lastName,
                                "email" : user.safeEmail
                            ]
                        ]
                        
                        self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                            guard error == nil else{
                                completion(false)
                                return
                            }
                            completion(true)
                        })
                    }
                })
        })
    }
    
    public func getAllUsers(completion : @escaping (Result<[[String:String]], Error>) -> Void){
        database.child("users").observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value as? [[String:String]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    public enum DatabaseError: Error{
        case failedToFetch
    }
}


//get reference to existing user array of above function
//need users array with multiple entries holding the name and safe email when adding user
//format is like this to save database calls
/*
 users =>[
                [
                    "name" :
                    "safe_email" :
                ],
                [
                    "name" :
                    "safe_email" :
                ]
            ]
            */


// MARK - Sending messages / conversations

extension DatabaseManager {
    
    
    /*
     every user will have this
     (conversation id)
     "slkgdfgkhj"{
        "messages" : [
            {
                "id" : String,
                "type" : text, photo, video
                "content" : String,
                "date" : Date(),
                "isRead" : true/false,
            }
        ]
     }
     
    conversations =>[
                   [
                       "conversation_id" (Unique identifier) : slkgdfgkhj:
                       "other_user_email" :
                        "latest_message" : => {
                            "date" : Date()
                            "latest_message" : "message"
                            "is_read" : true/false
                        }
                   ],
                   [
                       "name" :
                       "safe_email" :
                   ]
               ]
     

               */
    
    
    //create new conversatoin with target email and first message being sent
    //put convo in user convo collection
    //once put in, put root convo
    public func createNewConversation(With otherUserEmail : String, name : String, firstMessage: Message, completion : @escaping (Bool) -> Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
        let currentName = UserDefaults.standard.value(forKey: "name") as? String else{
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")

        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String : Any] else{
                completion(false)
                print("User not found")
                return
            }

            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)

            var message = ""

            switch firstMessage.kind{
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .custom(_):
                break
            }

            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationsData :[String : Any] = [
                "id" : conversationId,
                "other_user_email" : otherUserEmail,
                "name" : name,
                "latest_message" : [
                    "date" : dateString,
                    "message" : message,
                    "is_read" : false
                ]
            ]
            
            let recipient_newConversationsData :[String : Any] = [
                "id" : conversationId,
                "other_user_email" : safeEmail,
                "name" : currentName,
                "latest_message" : [
                    "date" : dateString,
                    "message" : message,
                    "is_read" : false
                ]
            ]
            
            //update recipient convo entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {[weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]]{
                    //append
                    conversations.append(recipient_newConversationsData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                }
                else{
                    //create new convo
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationsData])
                }
            })
            
            
            //the update current user convo entry
            //var bc we will append to it for current user
            if var conversations = userNode["conversations"] as? [[String: Any]]{
                //append
                conversations.append(newConversationsData)
                userNode["conversations"] = conversations
                ref.setValue(userNode, withCompletionBlock: {[weak self] error, _ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationID: conversationId,
                                                     firstMessage: firstMessage, completion: completion)
                })
            }
            else{
                //create new one of conversation array
                userNode["conversations"] = [
                    newConversationsData
                ]
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationID: conversationId,
                                                     firstMessage: firstMessage, completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversation(name: String, conversationID : String, firstMessage : Message,  completion : @escaping (Bool) -> Void){
//        {
//        "id" : String,
//        "type" : text, photo, video
//        "content" : String,
//        "date" : Date(),
//        "isRead" : true/false,
//        }
        
        var message = ""
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        switch firstMessage.kind{
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .custom(_):
            break
        }
        
        let collectionMessage : [String: Any] = [
            "id" : firstMessage.messageId,
            "type" : firstMessage.kind.messageKindString,
            "content" : message ,
            "date" : dateString,
            "sender_email" : currentUserEmail,
            "is_read" : false,
            "name" : name
        ]
        
        let value : [String: Any] = [
            "messages" : [
                collectionMessage
            
            ]
        ]
        
        print("Adding Convo : \(conversationID)")
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: {error , _ in
            guard error == nil else{
                completion(false)
                return
            }
            completion(true)
        })
        
    }
    
    //fetches and returns all convo for the user with passed in email
    public func getAllConversations(for email: String, completion : @escaping (Result<[Conversation], Error>) -> Void ){
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations : [Conversation] = value.compactMap({dictionary in
                guard let conversationId = dictionary["id"] as? String,
                    let name = dictionary["name"] as? String,
                    let otherUserEmail = dictionary["other_user_email"] as? String,
                    let latestMessage = dictionary["latest_message"] as? [String: Any],
                    let date = latestMessage["date"] as? String,
                    let message = latestMessage["message"] as? String,
                    let isRead = latestMessage["is_read"] as? Bool else{
                        return nil
                }
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMesseage: latestMessageObject)
                
            })
            completion(.success(conversations))
            
        })
    }
    
    //gets all messages for a given convo
    public func getAllMessagesForConversation(with id: String, completion : @escaping (Result<[Message], Error>) -> Void ){
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages : [Message] = value.compactMap({dictionary in
                guard let name = dictionary["name"] as? String,
                    let messageID = dictionary["id"] as? String,
                    let isRead = dictionary["is_read"] as? Bool,
                    let dateString = dictionary["date"] as? String,
                    let content = dictionary["content"] as? String,
                    let senderEmail = dictionary["sender_email"] as? String,
                    let type = dictionary["type"] as? String,
                    let date = ChatViewController.dateFormatter.date(from: dateString) else{
                        return nil
                }
                var kind : MessageKind?
                if type == "photo" {
                    //photo
                    guard let imageUrl = URL(string: content),
                    let placeholder = UIImage(systemName: "plus") else{
                        return nil
                    }
                    let media = Media(url: imageUrl, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                }
                else if type == "video" {
                    //photo
                    guard let videoUrl = URL(string: content),
                    let placeholder = UIImage(named: "video_placeholder") else{
                        return nil
                    }
                    //placeholder special for video, dont want to autoamtic play right away
                    //static asset report to have to press to play
                    let media = Media(url: videoUrl, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                    kind = .video(media)
                }
                else{
                    kind = .text(content)
                }
                
                guard let finalKind  = kind else{
                    return nil
                }
                
                let sender = Sender(photoURL: " ", senderId: senderEmail, displayName: name)
 
                //kind : is type
                return Message(sender: sender, messageId: messageID, sentDate: date, kind: finalKind)
            })
            completion(.success(messages))
            
        })
    }
    
    //sends messga ewith target convo and messages
    public func sendMessage(to conversation: String, otherUserEmail : String, name : String, newMessage: Message, completion : @escaping (Bool) -> Void){
        //add new message to messages
        //update sender latest message
        //update recipient latest message/
        //both spectic to message Key
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false)
            print("1")
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self]snapshot in
            guard let strongSelf = self else{
                return
            }
            guard var currentMessages = snapshot.value as? [[String : Any]] else{
                completion(false)
                print("2")
                return
            }
            
            var message = ""
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else{
                completion(false)
                print("3")
                return
            }
            
            switch newMessage.kind{
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                //allow us to referecne photo upload position where we want to render
                if let targetUrlString = mediaItem.url?.absoluteString{
                    message = targetUrlString
                }
                break
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString{
                    message = targetUrlString
                }
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .custom(_):
                break
            }
            
            let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            
            let newMessageEntry : [String: Any] = [
                "id" : newMessage.messageId,
                "type" : newMessage.kind.messageKindString,
                "content" : message ,
                "date" : dateString,
                "sender_email" : currentUserEmail,
                "is_read" : false,
                "name" : name
            ]
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages, withCompletionBlock: {error, _ in
                guard error == nil else {
                    completion(false)
                    print("4")
                    return
                }
                //get convo nodes for each user
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                    var databaseEntryConversations = [[String:Any]]()
                    let updatedValue : [String : Any] = [
                        "date" : dateString,
                        "is_read" : false,
                        "message" : message
                    ]
                    if var currentUserConversations = snapshot.value as? [[String : Any]]{
                        //could take way posistion and put in "for var conversation in currentMessages"
                        var position = 0
                        var targetConversation : [String: Any]?
                        //now find in covno with entry of id with current convo id, searching id
                        for conversationDictionary in currentUserConversations {
                            if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                targetConversation = conversationDictionary
                                break
                            }
                            position += 1
                        }
                        targetConversation?["latest_message"] = updatedValue
                        guard let finalConversation = targetConversation else{
                            completion(false)
                            print("6")
                            return
                        }
                        currentUserConversations[position] = finalConversation
                        databaseEntryConversations = currentUserConversations
                    }
                    else{
                        let newConversationsData :[String : Any] = [
                            "id" : conversation,
                            "other_user_email" : DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                            "name" : name,
                            "latest_message" : updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationsData
                        ]
                    }
                    
                    
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: {error, _ in
                        guard error == nil else{
                            completion(false)
                            print("7")
                            return
                        }
                        
                        // now must update latest message for recipient user
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                            guard var otherUserConversations = snapshot.value as? [[String : Any]] else{
                                completion(false)
                                print("8")
                                return
                            }
                             
                            let updatedValue : [String : Any] = [
                                "date" : dateString,
                                "is_read" : false,
                                "message" : message
                            ]
                            //could take way posistion and put in "for var conversation in currentMessages"
                            var position = 0
                            var targetConversation : [String: Any]?
                            //now find in covno with entry of id with current convo id, searching id
                            for conversationDictionary in otherUserConversations {
                                if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                    targetConversation = conversationDictionary
                                    break
                                }
                                position += 1
                            }
                            targetConversation?["latest_message"] = updatedValue
                            guard let finalConversation = targetConversation else{
                                completion(false)
                                print("10")
                                return
                            }
                            otherUserConversations[position] = finalConversation
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(otherUserConversations, withCompletionBlock: {error, _ in
                                guard error == nil else{
                                    completion(false)
                                    print("11")
                                    return
                                }
                                completion(true)
                            })
                        })
                    })
                })
            })
        })
    }
    
    public func deleteConversation(conversationId: String, completion : @escaping (Bool) -> Void){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        print("deleted convo with id : \(conversationId)")
        //get all convo from current user
        //delete convo in collection witt the target id
        //reset those convo for user in database
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value, with: {snapshot in
            if var conversations = snapshot.value as? [[String : Any]] {
                var positionToRemove = 0
                for conversation in conversations{
                    if let id = conversation["id"] as? String,
                        id == conversationId {
                        break
                    }
                    positionToRemove += 1
                }
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations, withCompletionBlock: {error, _ in
                    guard error == nil else{
                        completion(false)
                        print("failed to delete convo of making new convo array")
                        return
                    }
                    print("deleted convo")
                    completion(true)
                })
            }
        })
    }
    
    public func conversationExist(with targetRecipientEmail: String,  completion : @escaping (Result<String,Error>) -> Void ){
        let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        //on recipient userNode - want to get convo id - find if conversation collection has senderUser safe Email - thereby would exist
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
            guard let collection = snapshot.value as? [[String : Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            //iterate and find convo with target send
            if let conversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else{
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }){
                //get id bc it exist
                guard let id = conversation["id"] as? String else{
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            //id doesnt exist
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
    
    
}


struct ChatAppUser{
    let firstName: String
    let lastName: String
    let emailAddress: String
    var safeEmail : String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName: String{
//        images/brohiaarish-gmail-com_profile_picture.png
        return "\(safeEmail)_profile_picture.png"
    }
//    not good practice to have password
}




//    public func test(){
//        database.child("foo").setValue(["something" : true])
//    }
//    {
//    "foo" :  { }
//    }
