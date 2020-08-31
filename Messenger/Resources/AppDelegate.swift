//
//  AppDelegate.swift
//  Messenger
//
//  Created by Aarish  Brohi on 8/3/20.
//  Copyright © 2020 Aarish Brohi. All rights reserved.
//

import UIKit
import Firebase
import FBSDKCoreKit
import GoogleSignIn

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GIDSignInDelegate {

    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        FirebaseApp.configure()
          
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        GIDSignIn.sharedInstance()?.clientID = FirebaseApp.app()?.options.clientID
        GIDSignIn.sharedInstance()?.delegate = self

        return true
    }
          
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {

        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
        
        return GIDSignIn.sharedInstance().handle(url)

    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        guard error == nil else{
            if let error = error{
                print("Failed to sign in to google: \(error)")
            }
            return
        }
        
        guard let user = user else{
            return
        }
        
        print("Did sign in with Google:\(user)")
        
        guard let email = user.profile.email,
            let firstName = user.profile.givenName,
            let lastName = user.profile.familyName else{
                return
        }
        //save email bc storage bucket has exact version of email name to get access to picture
        UserDefaults.standard.set(email, forKey: "email")
        UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
            
        DatabaseManager.shared.userExists(with: email, completion: {exist in
            if !exist{
                let chatUser = ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email)
                DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                    if success{
                        //uploading image
                        
                        if user.profile.hasImage {
                            guard let url = user.profile.imageURL(withDimension: 200) else{
                                return
                            }
                            
                            URLSession.shared.dataTask(with: url, completionHandler: {data, _, _ in
                                guard let data = data else{
                                    return
                                }
                                let fileName  = chatUser.profilePictureFileName
                                StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName, completion: {result in
                                    switch result{
                                    case .success(let downloadUrl):
                                        UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                        print(downloadUrl)
                                    case .failure(let error):
                                        print("Storage Mamage Error: \(error)")
                                    }
                                })
                                //tells url task to begin
                            }).resume()
                        }
                    }
                    
                })
            }
        })
        
        
        guard let authentication = user.authentication else {
            print("Missing autho object from google user")
            return
        }
        let credential = GoogleAuthProvider.credential(withIDToken: authentication.idToken, accessToken: authentication.accessToken)
        
        FirebaseAuth.Auth.auth().signIn(with: credential, completion: {authResult, error in
            guard authResult != nil, error == nil else{
                print("failed to log in with google credentials")
                return
            }
            print("Succesful in signing with google cred.")
            NotificationCenter.default.post(name: .didLogInNotification, object: nil)
        })
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
       print("Google User was disconnected")
    }
    



}

    

