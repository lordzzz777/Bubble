//
//  UserModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 1/31/25.
//

import Foundation
import FirebaseFirestore

struct UserModel: Codable, Identifiable, Hashable {
    var id: String
    var nickname: String
    var imgUrl: String
    var lastConnectionTimeStamp: Timestamp
    var isOnline: Bool
    var chats: [String]
    var friends: [String]
    var isDeleted: Bool
    var encryptionPublicKey: String? = nil
    var blockedUsers: [String] = []
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = ["id": id,
                                  "nickname": nickname,
                                  "imgUrl": imgUrl,
                                  "lastConnectionTimeStamp": lastConnectionTimeStamp,
                                  "isOnline": isOnline,
                                  "chats": chats,
                                  "friends": friends,
                                  "isDeleted": isDeleted,
                                  "blockedUsers": blockedUsers
        ]
        if let encryptionPublicKey = encryptionPublicKey {
            dict["encryptionPublicKey"] = encryptionPublicKey
        }
        return dict
    }
}
