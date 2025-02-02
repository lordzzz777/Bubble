//
//  ChatsModels.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/2/25.
//

import Foundation
import FirebaseFirestore

struct ChatsModels: Codable, Hashable {
    var participants: [String] = []
    var lastMessage: String
    var lastMessageTimestamp: Date  // Convertimos de Timestamp a Date
    
    // Mapeo de nombres incorrectos en Firestore
    enum CodingKeys: String, CodingKey {
        case participants = "participats"  // Coincide con Firestore
        case lastMessage
        case lastMessageTimestamp = "lasttMessageTimestamp"  // Coincide con Firestore
    }
}

struct MessagesModels: Codable, Hashable {
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
