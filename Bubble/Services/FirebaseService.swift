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
}
