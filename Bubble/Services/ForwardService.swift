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
import FirebaseStorage


actor ForwardService{
    private let database = Firestore.firestore()
    private let messageEncryptionService = MessageEncryptionService()
    private let moderationService = ModerationService()
    
    /// Devuelve (o crea) el ID de un chat 1-a-1 entre `currentUID` y `contactUID`
    func ensurePrivateChat(with contactUID: String, currentUID: String) async throws -> String {
        do{
            try await moderationService.assertCanStartPrivateChat(with: contactUID)
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
    
    private func encryptedMessageIfNeeded(_ message: MessageModel, originalMessage: MessageModel, sourceChatID: String?, destinationChatID: String) async throws -> MessageModel {
        if message.type == .text, !message.content.isEmpty, message.content != "Mensaje eliminado" {
            let chatSnapshot = try await database.collection("chats").document(destinationChatID).getDocument()
            let participants = chatSnapshot.data()?["participants"] as? [String] ?? []
            let payload = try await messageEncryptionService.encryptText(
                message.content,
                replyingToText: message.replyingToText,
                chatID: destinationChatID,
                messageID: message.id,
                participantIDs: participants
            )
            
            var encryptedMessage = message
            encryptedMessage.content = "Mensaje cifrado"
            if payload.encryptedReplyingToText != nil {
                encryptedMessage.replyingToText = "Mensaje cifrado"
            }
            encryptedMessage.encryptedContent = payload.encryptedContent
            encryptedMessage.encryptedReplyingToText = payload.encryptedReplyingToText
            encryptedMessage.encryptedMessageKeys = payload.encryptedMessageKeys
            encryptedMessage.senderPublicKey = payload.senderPublicKey
            encryptedMessage.encryptionVersion = payload.encryptionVersion
            encryptedMessage.encryptionScheme = payload.encryptionScheme
            return encryptedMessage
        }
        
        guard originalMessage.encryptionVersion != nil,
              originalMessage.type == .image || originalMessage.type == .audio || originalMessage.type == .file,
              let sourceChatID else {
            return message
        }
        
        guard let url = URL(string: originalMessage.content) else { throw URLError(.badURL) }
        let (encryptedData, _) = try await URLSession.shared.data(from: url)
        let plainData = try await messageEncryptionService.decryptAttachmentData(encryptedData, message: originalMessage, chatID: sourceChatID)
        let payload = try await messageEncryptionService.encryptAttachmentData(plainData, chatID: destinationChatID, messageID: message.id)
        let storageURL = try await uploadForwardedAttachment(payload.encryptedData, message: message)
        
        var encryptedMessage = message
        encryptedMessage.content = storageURL
        encryptedMessage.encryptedMessageKeys = payload.encryptedMessageKeys
        encryptedMessage.senderPublicKey = payload.senderPublicKey
        encryptedMessage.encryptionVersion = payload.encryptionVersion
        encryptedMessage.encryptionScheme = payload.encryptionScheme
        return encryptedMessage
    }
    
    private func uploadForwardedAttachment(_ data: Data, message: MessageModel) async throws -> String {
        let folder: String
        switch message.type {
        case .image:
            folder = "chat_images"
        case .audio:
            folder = "voice_notes"
        case .file:
            folder = "shared_files"
        default:
            folder = "attachments"
        }
        
        let storageRef = Storage.storage().reference().child("\(folder)/\(message.id).bin")
        _ = try await storageRef.putDataAsync(data)
        return try await storageRef.downloadURL().absoluteString
    }
    
    /// Copia un mensaje (cualquier tipo) a múltiples chats destino
    func forward(_ messages: [MessageModel], to chatIDs: [String], sourceChatID: String? = nil) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        
        for chatID in chatIDs {
            try await moderationService.assertCanSendPrivateMessage(chatID: chatID)
            for var message in messages {
                let originalMessage = message
                message.id = UUID().uuidString
                message.senderUserID = currentUID
                message.timestamp = Timestamp(date: .now)
                message.isForwarded = true
                
                let forwardedMessage = try await encryptedMessageIfNeeded(message, originalMessage: originalMessage, sourceChatID: sourceChatID, destinationChatID: chatID)
                try await database.collection("chats")
                    .document(chatID)
                    .collection("messages")
                    .document(forwardedMessage.id)
                    .setData(forwardedMessage.dictionary)
                
                try await database.collection("chats").document(chatID).updateData([
                    "lastMessageTimestamp": forwardedMessage.timestamp,
                    "lastMessageSenderUserID": forwardedMessage.senderUserID,
                    "lastMessage": forwardedMessage.encryptionVersion == nil ? forwardedMessage.content : "Mensaje cifrado",
                    "lastMessageType": forwardedMessage.type.rawValue
                ])
            }
        }
    }
    
}
