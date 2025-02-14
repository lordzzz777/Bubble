//
//  AddNewFriendService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 2/9/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum AddNewFriendError: Error {
    case messageIdError
}

actor AddNewFriendService {
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    func searchFriendByNickname(_ nickname: String) async throws -> [UserModel] {
        do {
            let documents = try await database.collection("users")
                .whereField("nickname", isGreaterThanOrEqualTo: nickname)
                .whereField("nickname", isLessThanOrEqualTo: nickname + "\u{f8ff}") // Carácter Unicode especial para el final del rango // Esto me ayudó a entender que se podía https://qiita.com/TKG_KM/items/2678664d975812bea6c8
                .getDocuments()
            let documentsData = documents.documents.compactMap({$0})
            let matchedFriends = try documentsData.map { try $0.data(as: UserModel.self )}
            return matchedFriends
        } catch {
            throw error
        }
    }
    
    
    func sendFriendRequest(friendUID: String) async throws {
        Task {
            do {
                let currentUserInfo = try await self.getCurrentUserInfo()
                print("currentUserInfo: \(currentUserInfo)")
                let newFriendRequestMessage = MessageModel(id: UUID().uuidString, senderID: currentUserInfo.id, content: "\(currentUserInfo.nickname) quiere ser tu amigo", timestamp: Timestamp.init(), type: MessageType.friendRequest)
                let chat = ChatModel(id: UUID().uuidString, participants: [currentUserInfo.id, friendUID], lastMessage: newFriendRequestMessage.content, lastMessageTimestamp: newFriendRequestMessage.timestamp, messages: [newFriendRequestMessage])
                
                try await database.collection("users").document(friendUID).collection("chats").document(chat.id).setData(chat.dictionary)
            } catch {
                print("Error al enviar la solicitud: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    private func getCurrentUserInfo() async throws -> UserModel {
        do {
            let document = try await database.collection("users").document(uid).getDocument()
            guard let userData = try? document.data(as: UserModel.self) else {
                fatalError("No se pudo obtener el usuario")
            }
            print(userData)
            return userData
        } catch {
            throw error
        }
    }
}
