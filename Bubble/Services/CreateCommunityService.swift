//
//  CreateCommunityService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/12/25.
//

import Foundation
import FirebaseCore
import Firebase
import FirebaseAuth
@preconcurrency import FirebaseStorage

enum CreateCommunityError: Error {
    case uploadImageError
    case communityCheckingNameError
    case deleteImageFromStorageError
    case createCommunityError
    case invitationError
}

@MainActor
final class CreateCommunityService {
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    func fetchFriends() async throws -> [UserModel] {
        do {
            // Obteniendo la información del usuario
            let document = try await database.collection("users").document(uid).getDocument()
            let userData = try document.data(as: UserModel.self)
            let friendsUIDS = userData.friends
            print("friends UIDS: \(friendsUIDS)")
            // Obteniendo la información de los amigos del usuario
            var friends: [UserModel] = []
            for friendUID in friendsUIDS {
                let document = try await database.collection("users").document(friendUID).getDocument()
                let userData = try document.data(as: UserModel.self)
                friends.append(userData)
            }
            
            return friends
        } catch {
            throw error
        }
    }
    
    func uploadImage(image: UIImage, communityID: String) async throws -> String {
        let storage = Storage.storage()
        let storageRef = storage.reference().child("communities/\(communityID).jpg")
        
        guard let resizedImage = image.jpegData(compressionQuality: 0.1) else {
            print("Error: Could not resize image")
            return ""
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpg" //Setting metadata allows you to see console image in the web browser. This seteting will work for png as well as jpeg
    
        do {
            let _ = try await storageRef.putDataAsync(resizedImage, metadata: metadata)
            let imageURL = try await storageRef.downloadURL()
            return "\(imageURL)"
        } catch {
            print("Error: \(error.localizedDescription)")
            throw CreateCommunityError.uploadImageError
        }
    }
    
    func checkIfCommunityNotExistsBy(name: String) async throws -> Bool {
        do {
            let querySnapshot = try await database.collection("communities").whereField("name", isEqualTo: name).getDocuments()
            let documents = querySnapshot.documents.compactMap({$0})
            let communitiesData = documents.map { $0.data() }.compactMap{$0}
            
            return !communitiesData.isEmpty
        } catch {
            throw CreateCommunityError.communityCheckingNameError
        }
    }
    
    func removeImageFromFirebaseStorage(imageURL: String) async throws {
        guard let url = URL(string: imageURL) else {
            print("Error: Could not convert string to URL")
            return
        }
        
        let storageRef = Storage.storage().reference(forURL: url.absoluteString)
        do {
            try await storageRef.delete()
        } catch {
            throw CreateCommunityError.deleteImageFromStorageError
        }
    }
    
    func createCommunity(community: CommunityModel, friendToInviteIDs: [String] ) async throws {
        do {
            var newCommunity = community
            newCommunity.ownerUID = uid
            try await database.collection("communities").document(community.id).setData(newCommunity.dictionary)
            for friendToInviteID in friendToInviteIDs {
                try await self.sendCommunityInvitationTo(friendID: friendToInviteID)
            }
        } catch {
            throw CreateCommunityError.createCommunityError
        }
    }
    
    private func getChatIDInCommonWithUserBy(id: String) async throws -> String {
        do {
            let ref = try await database.collection("chats").getDocuments()
            let chats = try ref.documents.map { try $0.data(as: ChatModel.self) }
            let chatInCommon = chats.filter { $0.participants.contains(id) }
            
            return chatInCommon.first!.id
        } catch {
            throw error
        }
    }
    
    private func sendCommunityInvitationTo(friendID: String) async throws {
        do {
            let chatID = try await self.getChatIDInCommonWithUserBy(id: friendID)
            
            let message = MessageModel(senderUserID: uid, content: "", timestamp: .init(), type: MessageType.communityInvitation)
            try await database.collection("chats").document(chatID).collection("messages").addDocument(data: message.dictionary)
            
            // Actualizando información del chat
            let updateChatInfo: [String: Any] = [
                "lastMessageTimestamp": message.timestamp,
                "lastMessageSenderUserID": uid,
                "lastMessage": message.content,
                "lastMessageType": message.type.rawValue
            ]
            try await database.collection("chats").document(chatID).updateData(updateChatInfo)
        } catch {
            throw CreateCommunityError.invitationError
        }
    }
}
