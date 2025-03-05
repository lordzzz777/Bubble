//
//  ChatsModels.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/2/25.
//

import Foundation
import FirebaseFirestore
import FirebaseCore

struct ChatModel: Codable, Hashable {
    var id: String = ""
    var participants: [String] = []
    var lastMessage: String
    var lastMessageType: MessageType
    var lastMessageTimestamp: Timestamp
    var lastMessageSenderUserID: String
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "participants": participants,
            "lastMessage": lastMessage,
            "lastMessageType": lastMessageType.rawValue,
            "lastMessageTimestamp": lastMessageTimestamp,
            "lastMessageSenderUserID": lastMessageSenderUserID
        ]
    }
}

struct MessageModel: Codable, Hashable {
    var id: String = ""
    var senderUserID: String
    var content: String
    var timestamp: Timestamp
    var type: MessageType
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "senderUserID": senderUserID,
            "content": content,
            "timestamp": timestamp,
            "type": type.rawValue
        ]
    }
}

enum MessageType: String, Codable {
    case text
    case friendRequest
    case acceptedFriendRequest
    case image
    case video
}
