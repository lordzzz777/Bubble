//
//  FirebaseService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 1/31/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
@preconcurrency import FirebaseStorage

enum FirestoreError: Error {
    case newAccountError
    case checkNicknameError
    case uploadImageError
    case updateImageURLInDatabaseError
    case checkUserByIDError
}

actor FirestoreService {
    private let database = Firestore.firestore()
   
    var uid: String? {
        guard let user = Auth.auth().currentUser else {
            print("Intento de acceder a Firebase sin usuario autenticado.")
            return nil
        }
        return user.uid
    }
    
    func createUser(user: UserModel) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Error : No hay usuarios autenticados")
            return
        }
        
        do {
            if try await checkIfUserExistsByID(userID: uid ) {
                let newUserData: [String: Any] = ["nickname": user.nickname]
                try await database.collection("users").document(uid).updateData(newUserData)
            } else {
                try await database.collection("users").document(uid).setData(user.dictionary)
            }
        } catch {
            throw FirestoreError.newAccountError
        }
    }
    
    
    func checkIfNicknameNotExists(nickname: String) async throws -> Bool {
        do {
            let querySnapshot = try await database.collection("users").whereField("nickname", isEqualTo: nickname).getDocuments()
            let documents = querySnapshot.documents.compactMap({$0})
            let userData = documents.map { $0.data() }.compactMap{$0}
            
            return userData.isEmpty
        } catch {
            throw FirestoreError.checkNicknameError
        }
    }
    
    func checkIfUserExistsByID(userID: String) async throws -> Bool {
        do {
            let querySnapshot = try await database.collection("users").whereField("id", isEqualTo: userID).getDocuments()
            let documents = querySnapshot.documents
            print("Usuario existe: \(!documents.isEmpty)")
            return !documents.isEmpty
        } catch {
            print("Error: \(error)")
            return false
        }
    }
    
    func saveImage(image: UIImage) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Error : No hay usuarios autenticados")
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference().child("avatars/\(uid).jpg")
        
        guard let resizedImage = image.jpegData(compressionQuality: 0.1) else {
            print("Error: Could not resize image")
            return
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpg" //Setting metadata allows you to see console image in the web browser. This seteting will work for png as well as jpeg
        
        var imageURLString = ""
        
        do {
            let _ = try await storageRef.putDataAsync(resizedImage, metadata: metadata)
            
            do {
                let imageURL = try await storageRef.downloadURL()
                imageURLString = "\(imageURL)"
            } catch {
                print("Error: Could not get imageURL after saving image \(error.localizedDescription)")
                throw FirestoreError.updateImageURLInDatabaseError
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw FirestoreError.uploadImageError
        }
        
        do {
            
            if try await checkIfUserExistsByID(userID: uid) {
                try await database.collection("users").document(uid).updateData(["imgUrl": imageURLString])
            } else {
                let newUser = UserModel(
                    id: uid, nickname: "",
                    imgUrl: imageURLString,
                    lastConnectionTimeStamp: Timestamp.init(),
                    isOnline: true,
                    chats: [],
                    friends: []
                )
                
                try await self.createUser(user: newUser)
            }
            
            
        } catch {
            print("Error: \(error.localizedDescription)")
            throw FirestoreError.updateImageURLInDatabaseError
        }
    }
}


