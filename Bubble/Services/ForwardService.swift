//
//  ForwardService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 12/6/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore
import Firebase


actor ForwardService{
    
    /// Devuelve (o crea) el ID de un chat 1-a-1 entre `currentUID` y `contactUID`
    func ensurePrivateChat(with contactUID: String, currentUID: String) async throws -> String {
        let database = Firestore.firestore()
        do{
            // ¿ Ya exister?
            let query = try await database.collection("chats")
                .whereField("participants", arrayContains: currentUID)
                .getDocuments()
            if let doc = query.documents.first(where: { ($0["participants"] as? [String])?.contains(contactUID) == true }) {
                return doc.documentID
            }
            
            // crear chat nuevo
            let chatID = UUID().uuidString
            let chat = ChatModel(
                id:                 chatID,
                participants:       [currentUID, contactUID],
                lastMessage:        "",
                lastMessageType:    .text,
                lastMessageTimestamp: Timestamp(),
                lastMessageSenderUserID: currentUID
            )
            
            try await database.collection("chats").document(chatID).setData(chat.dictionary)
            return chatID
            
        }catch{
            
            throw error
        }
    }
    
    /// Copia un mensaje (cualquier tipo) a múltiples chats destino
    func forward(_ messages: [MessageModel], to chatIDs: [String]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for chatID in chatIDs {
                for var m in messages {
                    m.id         = UUID().uuidString
                    m.timestamp  = Timestamp(date: .now)
                    m.isForwarded = true
                    
                    let data = m.dictionary
                    group.addTask { [chatID, data] in
                        let db = Firestore.firestore()
                        try await db.collection("chats")
                            .document(chatID)
                            .collection("messages")
                            .document(data["id"] as! String)
                            .setData(data)
                    }
                }
            }
            try await group.waitForAll()
        }
    }
    
}
