//
//  ChatsModels.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/2/25.
//

import Foundation
import FirebaseFirestore
import FirebaseCore

/// Modelo que representa un chat privado entre usuarios.
struct ChatModel: Codable, Hashable {
    var id: String = ""
    var participants: [String] = []
    var lastMessage: String
    var lastMessageType: MessageType
    var lastMessageTimestamp: Timestamp
    var lastMessageSenderUserID: String
    var unreadCounts: [String: Int]? = nil
    var lastReadAt: [String: Timestamp]? = nil
    
    var dictionary: [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "participants": participants,
            "lastMessage": lastMessage,
            "lastMessageType": lastMessageType.rawValue,
            "lastMessageTimestamp": lastMessageTimestamp,
            "lastMessageSenderUserID": lastMessageSenderUserID
        ]
        if let unreadCounts { data["unreadCounts"] = unreadCounts }
        if let lastReadAt { data["lastReadAt"] = lastReadAt }
        return data
    }
}

/// Modelo que representa un chat público donde múltiples usuarios pueden participar.
struct PublicChatModel: Codable, Identifiable {
    var id: String = ""
    var participants: [String] // Lista de IDs de los usuarios en el chat
    var lastMessage: String
    var lastMessageTimestamp: Timestamp
    var messages: [MessageModel]
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "participants": participants,
            "lastMessage": lastMessage,
            "lastMessageTimestamp": lastMessageTimestamp,
            "messages": messages.map { $0.dictionary }
        ]
    }
}

/// Modelo que representa un mensaje dentro de un chat.
struct MessageModel: Identifiable, Codable, Hashable {
    var id: String = ""
    var senderUserID: String
    var content: String
    var timestamp: Timestamp
    var type: MessageType
    
    var replyToMessageID: String?
    var replyingToText: String?
    var replyingToNickname: String?
    
    var reactions:[String: String]? = nil // UserID : Emoji
    var audioDuration: Double?
    var attachmentFileName: String?
    var isForwarded: Bool? = false
    var encryptedContent: String?
    var encryptedReplyingToText: String?
    var encryptedMessageKeys: [String: String]?
    var senderPublicKey: String?
    var encryptionVersion: Int?
    var encryptionScheme: String?
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "senderUserID": senderUserID,
            "content": content,
            "timestamp": timestamp,
            "type": type.rawValue,
            "isForwarded": isForwarded ?? false
        ]
        if let replyingToMessageID = replyToMessageID {
            dict["replyingToMessageID"] = replyingToMessageID
        }
        if let replyingToText = replyingToText {
            dict["replyingToText"] = replyingToText
        }
        if let replyingToNickname = replyingToNickname {
            dict["replyingToNickname"] = replyingToNickname
        }
        if let attachmentFileName = attachmentFileName {
            dict["attachmentFileName"] = attachmentFileName
        }
        if let encryptedContent = encryptedContent {
            dict["encryptedContent"] = encryptedContent
        }
        if let encryptedReplyingToText = encryptedReplyingToText {
            dict["encryptedReplyingToText"] = encryptedReplyingToText
        }
        if let encryptedMessageKeys = encryptedMessageKeys {
            dict["encryptedMessageKeys"] = encryptedMessageKeys
        }
        if let senderPublicKey = senderPublicKey {
            dict["senderPublicKey"] = senderPublicKey
        }
        if let encryptionVersion = encryptionVersion {
            dict["encryptionVersion"] = encryptionVersion
        }
        if let encryptionScheme = encryptionScheme {
            dict["encryptionScheme"] = encryptionScheme
        }
        
        return dict
    }
}

/// Enum que define los diferentes tipos de mensajes en el chat.
enum MessageType: String, Codable {
    case text
    case friendRequest
    case acceptedFriendRequest
    case image
    case video
    case communityInvitation
    case audio
    case file
}
