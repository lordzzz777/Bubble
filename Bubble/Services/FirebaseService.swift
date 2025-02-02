//
//  FirebaseService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 1/31/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

actor FirebaseService {
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    func createUser(user: UserModel) async throws {
        do {
            try await database.collection("users").document(uid).setData(user.dictionary)
        } catch {
            throw error
        }
    }
    
    
    func checkIfNicknameNotExists(nickname: String) async throws -> Bool {
        do {
            let querySnapshot = try await database.collection("users").whereField("nickname", isEqualTo: nickname).getDocuments()
            let documents = querySnapshot.documents.compactMap({$0})
            let userData = documents.map { $0.data() }.compactMap{$0}
            
            return userData.isEmpty
        } catch {
            throw error
        }
    }
}
