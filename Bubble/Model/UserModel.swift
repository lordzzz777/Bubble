//
//  UserModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 1/31/25.
//

import Foundation
import FirebaseCore

struct UserModel: Codable {
    var id: String
    var nickname: String
    var imgUrl: String
    var lastConnectionTimeStamp: Timestamp
    var isOnline: Bool
    var chats: [String]
    var friends: [String]
    
    var dictionary: [String: Any] {
        return ["id": id, "nickname": nickname, "imgUrl": imgUrl, "lastConnectionTimeStamp": lastConnectionTimeStamp, "isOnline": isOnline, "chats": chats, "friends": friends]
    }
}
