//
//  AddNewFriendService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 2/9/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth


// Enum para definir posibles errores específicos en la gestión de amigos
enum AddNewFriendError: Error {
    case messageIdError
}


// Servicio para la gestión de amigos, utilizando Firestore y FirebaseAuth
actor AddNewFriendService {
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    

    /// Busca amigos por su nickname en la base de datos
    /// - Parameter nickname: El nickname que se desea buscar
    /// - Returns: Un array de usuarios que coinciden con el nickname
    func searchFriendByNickname(_ nickname: String) async throws -> [UserModel] {
        do {
            let documents = try await database.collection("users")
                .whereField("nickname", isGreaterThanOrEqualTo: nickname)
                .whereField("nickname", isLessThanOrEqualTo: nickname + "\u{f8ff}") // Carácter Unicode especial para el final del rango // Esto me ayudó a entender que se podía https://qiita.com/TKG_KM/items/2678664d975812bea6c8
                .getDocuments()
            let documentsData = documents.documents.compactMap({$0})
            let mappedUsers = try documentsData.map { try $0.data(as: UserModel.self )}
            let matchedFriends = mappedUsers.filter { $0.id != uid }
            return matchedFriends
        } catch {
            throw error
        }
    }
    
    /// Envía una solicitud de amistad al usuario con el UID especificado
    /// - Parameter friendUID: El UID del amigo al que se desea enviar la solicitud
    func sendFriendRequest(friendUID: String) async throws {
        Task {
            do {
                let currentUserInfo = try await self.getCurrentUserInfo()

                let newFriendRequestMessage = MessageModel(
                    id: UUID().uuidString,
                    senderUserID: currentUserInfo.id,
                    content: "",
                    timestamp: Timestamp.init(),
                    type: MessageType.friendRequest
                )
                
                let chat = ChatModel(
                    id: UUID().uuidString,
                    participants: [friendUID],
                    lastMessage: newFriendRequestMessage.content,
                    lastMessageType: newFriendRequestMessage.type,
                    lastMessageTimestamp: newFriendRequestMessage.timestamp,
                    lastMessageSenderUserID: newFriendRequestMessage.senderUserID
                )
                
                try await database.collection("chats").document(chat.id).setData(chat.dictionary)
                try await database.collection("chats").document(chat.id).collection("messages").addDocument(data: newFriendRequestMessage.dictionary)
            } catch {
                print("Error al enviar la solicitud: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    /// Checkea si el amigo tiene una solicitud de amistad pendiente enviada por nosotros.
    /// - Parameter friendUID: UID del amigo al que se desea enviar la solicitud
    /// - Returns: Boolean que indica si hay una solicitud pendiente
    func checkFriendIfFriendRequestPending(friendUID: String) async throws -> Bool {
        do {
            // Obtenemos la información del amigo al que queremos enviar la solicitud
            let document = try await database.collection("users").document(friendUID).getDocument()
            guard let userData = try? document.data(as: UserModel.self) else {
                fatalError("No se pudo obtener el usuario")
            }
            
            //Obtenemos los chats privados donde el amigo es participante, el último mensaje fue enviado por el usuario actual y el tipo de mensaje es "friendRequest"
            let documents = try await database.collection("chats")
                .whereField("participants", arrayContains: friendUID)
                .whereField("lastMessageSenderUserID", isEqualTo: uid)
                .whereField("lastMessageType", isEqualTo: MessageType.friendRequest.rawValue).getDocuments()
            let chatsData = try documents.documents.map { try $0.data(as: ChatModel.self) }.compactMap { $0 }
            
            print("Chats encontrados: \(chatsData)")
            
            // Si el array de chats no está vacío y si el amigo no está en la lista de amigos del usuario actual, entonces hay una solicitud pendiente
            return !chatsData.isEmpty && !userData.friends.contains(uid)
        } catch {
            throw error
        }
    }
    
    /// Obtiene la información del usuario actual desde Firestore
    /// - Returns: El modelo del usuario actual (UserModel)
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
    
    /// Actualiza el array de chats en el documento del usuario
    private func updateUserChats(userID: String, chatID: String) async throws {
        let userRef = database.collection("users").document(userID)
        
        do {
            try await userRef.updateData([
                "chats": FieldValue.arrayUnion([chatID]) // Añade el nuevo chat al array de chats
            ])
        } catch {
            print("Error al actualizar la lista de chats: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Método asincrónico que acepta una solicitud de amistad.
    /// Requiere el `ID` del chat donde se hizo la solicitud y el `UID` del usuario que la envió.
    /// Lanza errores si algo falla.
    func acceptFriendRequest(chatID: String, senderUID: String) async throws {
        let chatRef = database.collection("chats").document(chatID)
        
        do {
            let participants = [uid, senderUID]
            try await chatRef.updateData(["participants": participants])
            
            // Agregando mensajes
            let newAcceptedFriendRequestMessage: MessageModel = .init(senderUserID: uid, content: "", timestamp: .init(), type: .acceptedFriendRequest)
            try await chatRef.collection("messages").addDocument(data: newAcceptedFriendRequestMessage.dictionary)
            
            // Actualizando el chat
            let updateChatInfo: ChatModel = .init(id: chatID, participants: participants, lastMessage: "", lastMessageType: newAcceptedFriendRequestMessage.type, lastMessageTimestamp: newAcceptedFriendRequestMessage.timestamp, lastMessageSenderUserID: newAcceptedFriendRequestMessage.senderUserID)
            try await chatRef.updateData(updateChatInfo.dictionary)
            
            // Agregando los id de los usuarios a los amigos
            try await database.collection("users").document(uid).updateData([
                "friends": FieldValue.arrayUnion([senderUID])
            ])
            try await database.collection("users").document(senderUID).updateData([
                "friends": FieldValue.arrayUnion([uid])
            ])
        } catch {
            print("Error al aceptar la solicitud: \(error.localizedDescription)")
            throw error
        }
    }
}
