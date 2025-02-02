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
}

actor FirestoreService {
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    func createUser(user: UserModel) async throws {
        do {
            try await database.collection("users").document(uid).setData(user.dictionary)
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
    
    func saveImage(image: UIImage) async throws {
        let storage = Storage.storage()
        let storageRef = storage.reference().child("avatars/\(uid).jpg")
        
        guard let resizedImage = image.jpegData(compressionQuality: 0.3) else {
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
            throw FirestoreError.uploadImageError
        }
        
        do {
            try await database.collection("users").document(uid).updateData(["imgUrl": imageURLString])
        } catch {
            print("Error: \(error.localizedDescription)")
            throw FirestoreError.updateImageURLInDatabaseError
        }
    }
}
