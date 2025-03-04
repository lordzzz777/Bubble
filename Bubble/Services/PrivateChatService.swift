//
//  PrivateChatService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum PrivateChatServiceError: Error {
    case fetchingMessagesFailed
    case fetchingDocumentsFailed
}

class PrivateChatService {
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    func fetchMessagesFromChat(chatID: String, completionHandler: @escaping (Result<[MessageModel], Error>) -> Void) {
        database.collection("chats").document(chatID).collection("messages").addSnapshotListener {  query, error in
            if let error = error {
                print("Error fetching messages: \(error.localizedDescription)")
                completionHandler(.failure(PrivateChatServiceError.fetchingMessagesFailed))
                return
            }
            
            guard let documents = query?.documents else {
                completionHandler(.failure(PrivateChatServiceError.fetchingDocumentsFailed))
                return
            }
            
            print("documents: \(documents)")
            
            let messages = try! documents.map { try $0.data(as: MessageModel.self) }
            
            print("messages in service: \(messages)")
            
            completionHandler(.success(messages))
        }
    }
}
