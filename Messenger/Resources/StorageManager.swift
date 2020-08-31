//
//  StorageManager.swift
//  Messenger
//
//  Created by Aarish  Brohi on 8/10/20.
//  Copyright © 2020 Aarish Brohi. All rights reserved.
//

import Foundation
import FirebaseStorage

final class StorageManager{
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    /*
     images->username_ profilepicture.png
     images/brohiaarish-gmail-com_profile_picture.png
     */
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    //upload picure to firebase storage with a completition handler to return url string to downloard
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion){
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metedata, error in
            guard error == nil else{
                print("Failed to Upload picture firebase")
                completion(.failure(StorageErrors.failedToUploard))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL(completion: { url, error in
                guard let url = url else{
                    print("")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download Url returned: \(urlString)")
                completion(.success(urlString))
            })
            
        })
    }
    
    public enum StorageErrors : Error{
        case failedToUploard
        case failedToGetDownloadURL
    }
    
    public func downloadURL(for path: String, completion:  @escaping (Result<URL, Error>) ->Void){
        let reference = storage.child(path)
        reference.downloadURL(completion: { url, error in
            guard let url = url, error == nil else{
                completion(.failure(StorageErrors.failedToGetDownloadURL))
                return
            }
            completion(.success(url))
        })
    }
    
    
    //upload image what is sent as a photo message
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion){
        storage.child("message_images/\(fileName)").putData(data, metadata: nil, completion: {[weak self] metedata, error in
            guard error == nil else{
                print("Failed to Upload photo message firebase")
                completion(.failure(StorageErrors.failedToUploard))
                return
            }
            
            self?.storage.child("message_images/\(fileName)").downloadURL(completion: { url, error in
                guard let url = url else{
                    print("")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download Url returned: \(urlString)")
                completion(.success(urlString))
            })
            
        })
    }
    
    public func uploadMessageVideo(with fileUrl: URL, fileName: String, completion: @escaping UploadPictureCompletion){
        storage.child("message_videos/\(fileName)").putFile(from: fileUrl, metadata: nil, completion: {[weak self] metedata, error in
            guard error == nil else{
                print("Failed to Upload video file message firebase")
                completion(.failure(StorageErrors.failedToUploard))
                return
            }
            
            self?.storage.child("message_videos/\(fileName)").downloadURL(completion: { url, error in
                guard let url = url else{
                    print("")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download Url returned: \(urlString)")
                completion(.success(urlString))
            })
            
        })
    }
}
