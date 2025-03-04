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
    case sendMessageFailed
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
    
    @MainActor
    func sendMessage(chatID: String, messageText: String) async throws {
        do {
            // Enviando mensaje en el chat
            let message = MessageModel(senderUserID: uid, content: messageText, timestamp: .init(), type: MessageType.text)
            try await database.collection("chats").document(chatID).collection("messages").addDocument(data: message.dictionary)
            
            // Actualizando información del chat
            let updateChatInfo: [String: Any] = [
                "lastMessageTimestamp": message.timestamp,
                "lastMessageSenderUserID": uid,
                "lastMessage": message.content,
                "lastMessageType": message.type.rawValue
            ]
            try await database.collection("chats").document(chatID).updateData(updateChatInfo)
        } catch {
            throw PrivateChatServiceError.sendMessageFailed
        }
    }
}
