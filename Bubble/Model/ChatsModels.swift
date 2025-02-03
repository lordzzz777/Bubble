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
    var participants: [String] = [] 
    var lastMessage: String
    var lastMessageTimestamp: Timestamp
}

struct MessageModel: Codable, Hashable {
    var senderID: String
    var countent: String
    var timestamp: Timestamp
    var type: MessageType
}

enum MessageType: String, Codable {
    case text
    case image
    case video
}
