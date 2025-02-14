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
    @DocumentID var id: String?
    var participants: [String] = []
    var lastMessage: String
    var lastMessageTimestamp: Timestamp
}

struct MessageModel: Codable, Hashable {
    @DocumentID var id: String?
    var senderID: String
    var content: String
    var timestamp: Timestamp
    var type: MessageType
    
    var dictionary: [String: Any] {
        return [
            "id": id ?? UUID().uuidString,
            "senderID": senderID,
            "content": content,
            "timestamp": timestamp,
            "type": type.rawValue
        ]
    }
}

enum MessageType: String, Codable {
    case text
    case friendRequest
    case image
    case video
}
