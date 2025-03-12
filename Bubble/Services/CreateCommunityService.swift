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
}
