//
//  ChatViewController.swift
//  Messenger
//
//  Created by Aarish  Brohi on 8/8/20.
//  Copyright © 2020 Aarish Brohi. All rights reserved.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import Firebase
//for videos use
import AVFoundation
import AVKit

struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}

extension MessageKind{
    var messageKindString : String {
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributedText"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .custom(_):
            return "custom"
        }
    }
}

struct Media: MediaItem{
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

struct Sender: SenderType {
    public var photoURL: String
    public var senderId: String
    public var displayName: String
}

class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public let otherUserEmail: String
    private let conversationID : String?
    public var isNewConversation = false
    

    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(photoURL: "",
               senderId: safeEmail,
            displayName: "Me")
    }
    
    //optional bc when create new convo, there is no id
    init(with email:String, id :String? ) {
        self.conversationID = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        view.backgroundColor = .link
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setUpInputButton()
    }
    
    //set up phots messages for text
    private func setUpInputButton(){
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        //sf symbol => command space to find
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside({ [weak self]_ in
            self?.presentInputActionSheet()
        })
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet(){
        let actionsheet = UIAlertController(title: "Attach Media", message: "What would you like to attach",
                                            preferredStyle: .actionSheet)
        actionsheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: {[weak self] _ in
            self?.presentPhotoInputActionsheet()
        }))
        actionsheet.addAction(UIAlertAction(title: "Video", style: .default, handler: {[weak self] _ in
            self?.presentVideoInputActionsheet()
            
        }))
        actionsheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: { _ in
            
        }))
        actionsheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionsheet,animated: true)
    }
    
    private func presentPhotoInputActionsheet(){
        let actionsheet = UIAlertController(title: "Attach Photo", message: "Where would you like to attach photo from?",
                                            preferredStyle: .actionSheet)
        actionsheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated : true)
        }))
        actionsheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated : true)
        }))
        actionsheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionsheet,animated: true)
    }
    
    private func presentVideoInputActionsheet(){
        let actionsheet = UIAlertController(title: "Attach Video", message: "Where would you like to attach video from?",
                                            preferredStyle: .actionSheet)
        actionsheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated : true)
        }))
        actionsheet.addAction(UIAlertAction(title: "Library", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated : true)
        }))
        actionsheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionsheet,animated: true)
    }
    
    
    private func listenForMessages(id: String, shouldScrolltoBottom : Bool){
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: {[weak self] result in
            switch result{
            case .success(let messsages):
                guard !messsages.isEmpty else{
                    return
                }
                self?.messages = messsages
                
                //user scroll to top , new message not to be down
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrolltoBottom{
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                    
                }
                
            case .failure(let error):
                print("failed to get message: \(error)")
            }
        })
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationID  = conversationID {
            listenForMessages(id: conversationID, shouldScrolltoBottom : true)
        }
    }
    
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let messageId = createMessageId(),
            let conversationId = conversationID,
            let name = self.title,
            let selfSender = self.selfSender else{
                return
        }
        if let image = info[.editedImage] as? UIImage,
            let imageData = image.pngData() {
            //assume uploading a message
            
            let fileName = "photo_messaage_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            
            //upload image then send image
            //must get data of image
            
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: {[weak self]result in
                guard let strongSelf = self else{
                    return
                }
                switch result{
                case .success(let urlString):
                    //ready to send message
                    print("Uploaded Messsage Photo : \(urlString)")
                    
                    //kind : photo(MediaItem) -> define media item which is phot video or audio
                    //created strcut on top
                    
                    guard let url = URL(string: urlString),
                        let placeholder = UIImage(systemName: "plus") else{
                            return
                    }
                    
                    //placeholder nonoptional must have something placed, plus image just chosen for fun
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .photo(media))
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: {success in
                        if success {
                            print("sent photo message")
                        }
                        else{
                            print("failed to send photo message")
                        }
                        
                    })
                case .failure(let error):
                    print("message photo upload error: \(error)")
                }
            })
        }
        else if let videoUrl = info[.mediaURL] as? URL{
            //assume uploading a video
            
            let fileName = "photo_messaage_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            //upload video
            //identical measures in uploading a video just as photo, first uplaod video
            //then to message via data manager
            //video does not have imageData unlike photos bc it is a very large file and good practice to
            //just have the URL instead
            
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: {[weak self]result in
                guard let strongSelf = self else{
                    return
                }
                switch result{
                case .success(let urlString):
                    //ready to send message
                    print("Uploaded Messsage Video : \(urlString)")
                    
                    //kind : photo(MediaItem) -> define media item which is phot video or audio
                    //created strcut on top
                    guard let url = URL(string: urlString),
                        let placeholder = UIImage(systemName: "plus") else{
                            return
                    }
                    
                    //placeholder nonoptional must have something placed, plus image just chosen for fun
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .video(media))
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: {success in
                        if success {
                            print("sent video message")
                        }
                        else{
                            print("failed to send video message")
                        }
                        
                    })
                case .failure(let error):
                    print("message photo upload error: \(error)")
                }
            })
        }
    }
}
 
extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate{
    //who is current sender, how framworkks diecide if chat bubble on right or left
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self Sender is nil email should be catched")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        //use section bc it is collection of messages., message framawork uses section to sperate section
        //message can have different types of data thereby section covers it all not count
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    //download images to not have placeholder of plus sign
    //to put actual photo for text
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else{
            return
        }
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else{
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
    }
}

extension ChatViewController : InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
            let selfSender = self.selfSender,
            let messageId = createMessageId()
        else{
            return
        }
        print("Sending: \(text)")
        let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .text(text))
        //send message
        if isNewConversation{
            //create convo in database
            //messageid is a unique string for all messages
            DatabaseManager.shared.createNewConversation(With: otherUserEmail, name : self.title ?? "User",
                                                         firstMessage: message, completion: {[weak self]success in
                if success{
                    print("message sent")
                    self?.isNewConversation = false
                }
                else{
                    print("failed to send")
                }
            })
        }
        else{
            guard let conversationID = conversationID,
                let name = self.title else{
                return
            }
            //when a new message is sent - needs to have content, data, id, is _ read,
            //append to an existing user converation data
            DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail : otherUserEmail, name: name, newMessage: message, completion: { success in
                if success{
                    print("message sent")
                }
                else{
                    print("failed to send message wow ")
                }
            })
        }
    }
    
    private func createMessageId() -> String? {
        //date, other user email, and sender email
        //give random enough string, and a random int incase
        let dateString = Self.dateFormatter.string(from: Date())
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let newIdentifier = "\(otherUserEmail)_\( safeCurrentEmail)_ \(dateString)"
        print("created message id \(newIdentifier)")
        return newIdentifier
    }
}

//extension for tapping on image to make it full screen
extension ChatViewController : MessageCellDelegate {
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        let message = messages[indexPath.section]
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else{
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else{
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            present(vc, animated: true)
        default:
            break
        }
    }
}
