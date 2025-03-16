//
//  CommunityModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/16/25.
//

import Foundation
import FirebaseCore

struct CommunityModel: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var imgUrl: String
    var createdAt: Timestamp
    var ownerUID: String
    var lastMessage: String
    var messages: [CommunityMessageModel]
    var admins: [AdminModel]
    var members: [String]
    var blockedUsers: [String]
}

struct AdminModel: Codable, Identifiable {
    var id: String
    var role: AdminRole
    var canRead: Bool
    var canWrite: Bool
    var canInvite: Bool
    var canKick: Bool
    var canMute: Bool
    var canChangeRole: Bool
}

enum AdminRole: String, Codable {
    case owner
    case admin
    case moderator
}


struct CommunityMessageModel: Codable, Hashable {
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
