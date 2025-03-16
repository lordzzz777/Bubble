//
//  CreateCommunityService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/12/25.
//

import Foundation
import FirebaseCore
import Firebase
import FirebaseAuth
@preconcurrency import FirebaseStorage

enum CreateCommunityError: Error {
    case uploadImageError
}

final class CreateCommunityService {
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    @MainActor
    func fetchFriends() async throws -> [UserModel] {
        do {
            // Obteniendo la información del usuario
            let document = try await database.collection("users").document(uid).getDocument()
            let userData = try document.data(as: UserModel.self)
            let friendsUIDS = userData.friends
            print("friends UIDS: \(friendsUIDS)")
            // Obteniendo la información de los amigos del usuario
            var friends: [UserModel] = []
            for friendUID in friendsUIDS {
                let document = try await database.collection("users").document(friendUID).getDocument()
                let userData = try document.data(as: UserModel.self)
                friends.append(userData)
            }
            
            return friends
        } catch {
            throw error
        }
    }
    
    @MainActor
    func uploadImage(image: UIImage, communityID: String) async throws -> String {
        let storage = Storage.storage()
        let storageRef = storage.reference().child("communities/\(communityID).jpg")
        
        guard let resizedImage = image.jpegData(compressionQuality: 0.1) else {
            print("Error: Could not resize image")
            return ""
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpg" //Setting metadata allows you to see console image in the web browser. This seteting will work for png as well as jpeg
    
        do {
            let _ = try await storageRef.putDataAsync(resizedImage, metadata: metadata)
            let imageURL = try await storageRef.downloadURL()
            return "\(imageURL)"
        } catch {
            print("Error: \(error.localizedDescription)")
            throw CreateCommunityError.uploadImageError
        }
    }
}
