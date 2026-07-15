//
//  FirebaseService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 1/31/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
@preconcurrency import FirebaseStorage

enum FirestoreError: Error {
    case newAccountError
    case checkNicknameError
    case uploadImageError
    case updateImageURLInDatabaseError
    case checkUserByIDError
    case deleteAccountError
    case requiresRecentLogin
}

actor FirestoreService {
    private let database = Firestore.firestore()
   
    /// Obtiene el UID del usuario autenticado en Firebase.
    ///
    /// - Returns: El UID del usuario autenticado si existe, `nil` si no hay usuario autenticado.
    var uid: String? {
        guard let user = Auth.auth().currentUser else {
            AppLogger.warning("Intento de acceder a Firebase sin usuario autenticado.")
            return nil
        }
        return user.uid
    }
    
    /// Crea o actualiza un usuario en Firestore.
    ///
    /// - Parameter user: El modelo de usuario que se desea almacenar.
    /// - Throws: Lanza un error `FirestoreError.newAccountError` en caso de fallo en la escritura de datos.
    func createUser(user: UserModel) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            AppLogger.warning("No hay usuario autenticado.")
            return
        }
        
        do {
            let document = try await database.collection("users").document(uid).getDocument()
            
            if let data = document.data(), let isDeleted = data["isDeleted"] as? Bool, isDeleted {
                // Reactivar usuario si estaba eliminado
                try await database.collection("users").document(uid).updateData([
                    "isDeleted": false,
                    "nickname": user.nickname,
                    "imgUrl": user.imgUrl,
                    "lastConnectionTimeStamp": Timestamp(),
                    "isOnline": true,
                ])
                AppLogger.info("Cuenta reactivada.")
            } else {
                if try await checkIfUserExistsByID(userID: uid) {
                    try await database.collection("users").document(uid).updateData(["nickname": user.nickname])
                } else {
                    var userData = user.dictionary
                    userData["isDeleted"] = false // Asegurar que la cuenta nueva no esté eliminada
                    try await database.collection("users").document(uid).setData(userData)
                }
            }
            
//            // Agregar usuario al chat público asegurando que se cree si no existe
//            try await addUserToPublicChat(userID: uid)
            
        } catch {
            AppLogger.error("Error al crear usuario.")
            throw FirestoreError.newAccountError
        }
    }
    
    /// Verifica si un nickname ya está en uso en la colección de usuarios de Firestore.
    ///
    /// - Parameter nickname: El nickname que se desea verificar.
    /// - Returns: `true` si el nickname no existe en la base de datos, `false` si ya está en uso.
    /// - Throws: Lanza un error `FirestoreError.checkNicknameError` en caso de fallo en la consulta.
    func checkIfNicknameNotExists(nickname: String) async throws -> Bool {
        do {
            let querySnapshot = try await database.collection("users")
                .whereField("nickname", isEqualTo: nickname)
                .whereField("isDeleted", isEqualTo: false)
                .getDocuments()
            let documents = querySnapshot.documents.compactMap({$0})
            let userData = documents.map { $0.data() }.compactMap{$0}
            
            return userData.isEmpty
        } catch {
            throw FirestoreError.checkNicknameError
        }
    }
    
    /// Verifica si un usuario con un ID específico existe en la base de datos de Firestore.
    ///
    /// - Parameter userID: El identificador único del usuario a verificar.
    /// - Returns: `true` si el usuario existe en la base de datos, `false` si no existe.
    /// - Throws: En caso de un error en la consulta, se captura y devuelve `false` en lugar de propagar la excepción.
    func checkIfUserExistsByID(userID: String) async throws -> Bool {
        do {
            
            let querySnapshot = try await database.collection("users")
                .whereField("id", isEqualTo: userID)
                .whereField("isDeleted", isEqualTo: false)
                .getDocuments()
            
            let documents = querySnapshot.documents
            AppLogger.debug("Consulta de existencia de usuario completada.")
            
            return !documents.isEmpty
            
        } catch {
            AppLogger.error("Error al comprobar usuario.")
            return false
        }
    }
    
    /// Guarda una imagen en Firebase Storage y actualiza la URL en Firestore.
    ///
    /// - Parameter image: La imagen `UIImage` que se desea almacenar.
    /// - Throws: Lanza un error `FirestoreError.uploadImageError` si falla la carga,
    ///           o `FirestoreError.updateImageURLInDatabaseError` si falla la actualización en Firestore.
    func saveImage(image: UIImage) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            AppLogger.warning("No hay usuario autenticado.")
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference().child("avatars/\(uid).jpg")
        
        guard let resizedImage = image.jpegData(compressionQuality: 0.1) else {
            AppLogger.error("No se pudo redimensionar la imagen de perfil.")
            return
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpg" //Setting metadata allows you to see console image in the web browser. This seteting will work for png as well as jpeg
        
        var imageURLString = ""
        
        do {
            let _ = try await storageRef.putDataAsync(resizedImage, metadata: metadata)
            
            do {
                let imageURL = try await storageRef.downloadURL()
                imageURLString = "\(imageURL)"
            } catch {
                AppLogger.error("No se pudo obtener la URL de imagen tras guardar.")
                throw FirestoreError.updateImageURLInDatabaseError
            }
        } catch {
            AppLogger.error("Error en operación de Firestore.")
            throw FirestoreError.uploadImageError
        }
        
        do {
            
            if try await checkIfUserExistsByID(userID: uid) {
                try await database.collection("users").document(uid).updateData(["imgUrl": imageURLString])
            } else {
                let newUser = UserModel(
                    id: uid, nickname: "",
                    imgUrl: imageURLString,
                    lastConnectionTimeStamp: Timestamp.init(),
                    isOnline: true,
                    chats: [],
                    friends: [],
                    isDeleted: false,
                    encryptionPublicKey: nil,
                    blockedUsers: []
                )
                
                try await self.createUser(user: newUser)
            }
            
            
        } catch {
            AppLogger.error("Error en operación de Firestore.")
            throw FirestoreError.updateImageURLInDatabaseError
        }
    }
    
    /// Obtiene los datos del usuario autenticado desde Firestore.
    ///
    /// - Returns: Un objeto `UserModel` con los datos del usuario si existe, `nil` si el usuario no está en la base de datos.
    /// - Throws: Lanza un error `FirestoreError.checkUserByIDError` si ocurre un problema al obtener los datos.
    func getUserData() async throws -> UserModel? {
        guard let uid = self.uid else {
            throw FirestoreError.checkUserByIDError
        }
        
        do {
            let document = try await database.collection("users").document(uid).getDocument()
            
            if !document.exists {
                AppLogger.warning("El usuario autenticado no existe en la base de datos.")
                return nil
            }
            
            guard let data = document.data() else {
                AppLogger.warning("El documento de usuario existe pero no tiene datos.")
                return nil
            }
            
            return UserModel(
                id: uid,
                nickname: data["nickname"] as? String ?? "",
                imgUrl: data["imgUrl"] as? String ?? "",
                lastConnectionTimeStamp: data["lastConnectionTimeStamp"] as? Timestamp ?? Timestamp(),
                isOnline: data["isOnline"] as? Bool ?? false,
                chats: data["chats"] as? [String] ?? [],
                friends: data["friends"] as? [String] ?? [],
                isDeleted: false,
                encryptionPublicKey: data["encryptionPublicKey"] as? String,
                blockedUsers: data["blockedUsers"] as? [String] ?? []
            )
            
        } catch {
            AppLogger.error("Error al obtener los datos del usuario.")
            throw FirestoreError.checkUserByIDError
        }
    }
    
    /// Actualiza el nickname del usuario si no está en uso.
    ///
    /// - Parameter newNickname: El nuevo nickname que se desea asignar.
    /// - Throws: Lanza un error `FirestoreError.checkNicknameError` si ocurre un problema en la validación o actualización.
    func updateNickname(newNickname: String ) async throws {
        guard let uid = self.uid else {
            AppLogger.warning("No hay usuario autenticado.")
            return
        }
        
        do{
            let isAvalible = try await checkIfNicknameNotExists(nickname: newNickname)
            guard isAvalible else {
                AppLogger.info("El nickname ya está en uso.")
                return
            }
            try await database.collection("users").document(uid).updateData(["nickname": newNickname])
            AppLogger.info("Nickname actualizado correctamente.")
        }catch{
            throw FirestoreError.checkNicknameError
        }
    }

    /// Elimina la cuenta del usuario autenticado y borra o anonimiza sus datos personales.
    func deleteCurrentUserAccount() async throws {
        guard let authUser = Auth.auth().currentUser else {
            throw FirestoreError.checkUserByIDError
        }
        let uid = authUser.uid
        let userRef = database.collection("users").document(uid)
        let userSnapshot = try await userRef.getDocument()
        let userData = userSnapshot.data()
        let avatarURL = userData?["imgUrl"] as? String ?? ""
        let nickname = userData?["nickname"] as? String ?? ""
        
        do {
            try await removeAvatarIfNeeded(avatarURL)
            try await removeStorageFilesFromMessagesSentByDeletedUser(uid: uid)
            try await removeCommunityImagesOwnedByDeletedUser(uid: uid)
            try await removeUserFromFriendsLists(uid: uid)
            try await removeUserFromBlockedLists(uid: uid)
            try await removeUserFromChats(uid: uid)
            try await removeUserFromPublicChat(uid: uid)
            try await anonymizeReportsInvolvingDeletedUser(uid: uid)
            try await redactMessageRepliesToDeletedUser(nickname: nickname)
            try await redactMessagesSentByDeletedUser(uid: uid)
            try await userRef.delete()
            try await authUser.delete()
        } catch let error as NSError where error.domain == AuthErrorDomain && error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            throw FirestoreError.requiresRecentLogin
        } catch {
            throw FirestoreError.deleteAccountError
        }
    }
    
    /// Oculta la cuenta del usuario marcándola como eliminada en Firestore.
    ///
    /// - Throws: Lanza un error si no se puede actualizar el estado del usuario en Firestore.
    func setUserInvisible() async throws {
        try await deleteCurrentUserAccount()
    }
    
    private func removeAvatarIfNeeded(_ avatarURL: String) async throws {
        guard avatarURL.isEmpty == false else { return }
        let ref = Storage.storage().reference(forURL: avatarURL)
        try? await ref.delete()
    }
    
    private func removeStorageFilesFromMessagesSentByDeletedUser(uid: String) async throws {
        let messagesSnapshot = try await database.collectionGroup("messages")
            .whereField("senderUserID", isEqualTo: uid)
            .getDocuments()
        
        for document in messagesSnapshot.documents {
            let data = document.data()
            let type = data["type"] as? String ?? ""
            let content = data["content"] as? String ?? ""
            
            guard ["image", "audio", "file"].contains(type) else { continue }
            await deleteStorageFileIfPossible(content)
            try await redactDeletedAttachmentMessage(document.reference)
        }
    }
    
    private func deleteStorageFileIfPossible(_ storageURL: String) async {
        guard storageURL.hasPrefix("https://") || storageURL.hasPrefix("gs://") else { return }
        do {
            let ref = Storage.storage().reference(forURL: storageURL)
            try await ref.delete()
        } catch {
            AppLogger.warning("No se pudo borrar un archivo de Storage durante la eliminación de cuenta.")
        }
    }
    
    private func redactDeletedAttachmentMessage(_ messageRef: DocumentReference) async throws {
        try await messageRef.updateData([
            "content": "Archivo eliminado",
            "attachmentFileName": FieldValue.delete(),
            "encryptedContent": FieldValue.delete(),
            "encryptedReplyingToText": FieldValue.delete(),
            "encryptedMessageKeys": FieldValue.delete(),
            "senderPublicKey": FieldValue.delete(),
            "encryptionVersion": FieldValue.delete(),
            "encryptionScheme": FieldValue.delete()
        ])
    }
    
    private func removeCommunityImagesOwnedByDeletedUser(uid: String) async throws {
        let communitiesSnapshot = try await database.collection("communities")
            .whereField("ownerUID", isEqualTo: uid)
            .getDocuments()
        
        for document in communitiesSnapshot.documents {
            let imageURL = document.data()["imgUrl"] as? String ?? ""
            await deleteStorageFileIfPossible(imageURL)
            try await document.reference.updateData(["imgUrl": ""])
        }
    }
    
    private func removeUserFromFriendsLists(uid: String) async throws {
        let friendsSnapshot = try await database.collection("users")
            .whereField("friends", arrayContains: uid)
            .getDocuments()
        
        for document in friendsSnapshot.documents {
            try await document.reference.updateData([
                "friends": FieldValue.arrayRemove([uid])
            ])
        }
    }
    
    private func removeUserFromBlockedLists(uid: String) async throws {
        let blockedSnapshot = try await database.collection("users")
            .whereField("blockedUsers", arrayContains: uid)
            .getDocuments()
        
        for document in blockedSnapshot.documents {
            try await document.reference.updateData([
                "blockedUsers": FieldValue.arrayRemove([uid])
            ])
        }
    }
    
    private func removeUserFromChats(uid: String) async throws {
        let chatsSnapshot = try await database.collection("chats")
            .whereField("participants", arrayContains: uid)
            .getDocuments()
        
        for document in chatsSnapshot.documents {
            try await document.reference.updateData([
                "participants": FieldValue.arrayRemove([uid])
            ])
        }
    }
    
    private func removeUserFromPublicChat(uid: String) async throws {
        let publicChatRef = database.collection("public_chats").document("global_chat")
        try? await publicChatRef.updateData([
            "participants": FieldValue.arrayRemove([uid])
        ])
    }
    
    private func anonymizeReportsInvolvingDeletedUser(uid: String) async throws {
        let reportsByDeletedUser = try await database.collection("reports")
            .whereField("reporterUserID", isEqualTo: uid)
            .getDocuments()
        
        for document in reportsByDeletedUser.documents {
            try await document.reference.updateData([
                "reporterUserID": "deleted_user"
            ])
        }
        
        let reportsAboutDeletedUser = try await database.collection("reports")
            .whereField("reportedUserID", isEqualTo: uid)
            .getDocuments()
        
        for document in reportsAboutDeletedUser.documents {
            try await document.reference.updateData([
                "reportedUserID": "deleted_user"
            ])
        }
    }
    
    private func redactMessageRepliesToDeletedUser(nickname: String) async throws {
        guard nickname.isEmpty == false else { return }
        let repliesSnapshot = try await database.collectionGroup("messages")
            .whereField("replyingToNickname", isEqualTo: nickname)
            .getDocuments()
        
        for document in repliesSnapshot.documents {
            try await document.reference.updateData([
                "replyingToText": FieldValue.delete(),
                "replyingToNickname": "Usuario eliminado",
                "encryptedReplyingToText": FieldValue.delete()
            ])
        }
    }
    
    private func redactMessagesSentByDeletedUser(uid: String) async throws {
        let messagesSnapshot = try await database.collectionGroup("messages")
            .whereField("senderUserID", isEqualTo: uid)
            .getDocuments()
        
        for document in messagesSnapshot.documents {
            let type = document.data()["type"] as? String ?? ""
            let replacementContent = ["image", "audio", "file"].contains(type) ? "Archivo eliminado" : "Mensaje eliminado"
            try await document.reference.updateData([
                "senderUserID": "deleted_user",
                "content": replacementContent,
                "replyingToText": FieldValue.delete(),
                "replyingToNickname": FieldValue.delete(),
                "encryptedContent": FieldValue.delete(),
                "encryptedReplyingToText": FieldValue.delete(),
                "encryptedMessageKeys": FieldValue.delete(),
                "senderPublicKey": FieldValue.delete(),
                "encryptionVersion": FieldValue.delete(),
                "encryptionScheme": FieldValue.delete(),
                "attachmentFileName": FieldValue.delete()
            ])
        }
        
        let chatsSnapshot = try await database.collection("chats")
            .whereField("lastMessageSenderUserID", isEqualTo: uid)
            .getDocuments()
        
        for document in chatsSnapshot.documents {
            try await document.reference.updateData([
                "lastMessageSenderUserID": "deleted_user",
                "lastMessage": "Mensaje eliminado"
            ])
        }
    }
    
    func updateUserStatus(isOnline: Bool) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {return}
        
        try await database.collection("users").document(uid).updateData([
            "isOnline": isOnline
        ])
    }
    
    func storeLastSeen() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {return}
        
        try await database.collection("users").document(uid).updateData([
            "lastConnectionTimeStamp": Timestamp()
        ])
    }
}


