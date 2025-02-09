//
//  AddNewFriendService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 2/9/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

actor AddNewFriendService {
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    func searchFriendByNickname(_ nickname: String) async throws -> [UserModel] {
        do {
            let documents = try await database.collection("users")
                .whereField("nickname", isGreaterThanOrEqualTo: nickname)
                .whereField("nickname", isLessThanOrEqualTo: nickname + "\u{f8ff}") // Carácter Unicode especial para el final del rango
                .getDocuments()
            let documentsData = documents.documents.compactMap({$0})
            let matchedFriends = try documentsData.map { try $0.data(as: UserModel.self )}
            return matchedFriends
        } catch {
            throw error
        }
    }
}
