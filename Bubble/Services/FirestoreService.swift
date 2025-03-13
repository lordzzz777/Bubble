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
}

actor FirestoreService {
    private let database = Firestore.firestore()
   
    /// Obtiene el UID del usuario autenticado en Firebase.
    ///
    /// - Returns: El UID del usuario autenticado si existe, `nil` si no hay usuario autenticado.
    var uid: String? {
        guard let user = Auth.auth().currentUser else {
            print("Intento de acceder a Firebase sin usuario autenticado.")
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
            print("❌ Error: No hay usuario autenticado.")
            return
        }
        
        do {
            let document = try await database.collection("users").document(uid).getDocument()
            
            if let data = document.data(), let isDeleted = data["isDeleted"] as? Bool, isDeleted {
                // 🔄 Reactivar usuario si estaba eliminado
                try await database.collection("users").document(uid).updateData([
                    "isDeleted": false,
                    "nickname": user.nickname,
                    "imgUrl": user.imgUrl,
                    "lastConnectionTimeStamp": Timestamp(),
                    "isOnline": true,
                ])
                print("✅ Cuenta reactivada para UID: \(uid)")
            } else {
                if try await checkIfUserExistsByID(userID: uid) {
                    try await database.collection("users").document(uid).updateData(["nickname": user.nickname])
                } else {
                    var userData = user.dictionary
                    userData["isDeleted"] = false // Asegurar que la cuenta nueva no esté eliminada
                    try await database.collection("users").document(uid).setData(userData)
                }
            }
            
            // 🔹 Agregar usuario al chat público asegurando que se cree si no existe
            try await addUserToPublicChat(userID: uid)
            
        } catch {
            print("❌ Error al crear usuario: \(error.localizedDescription)")
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
            print("Usuario existe: \(!documents.isEmpty)")
            
            return !documents.isEmpty
            
        } catch {
            print("Error: \(error)")
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
            print("Error : No hay usuarios autenticados")
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference().child("avatars/\(uid).jpg")
        
        guard let resizedImage = image.jpegData(compressionQuality: 0.1) else {
            print("Error: Could not resize image")
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
                print("Error: Could not get imageURL after saving image \(error.localizedDescription)")
                throw FirestoreError.updateImageURLInDatabaseError
            }
        } catch {
            print("Error: \(error.localizedDescription)")
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
                    isDeleted: false
                )
                
                try await self.createUser(user: newUser)
            }
            
            
        } catch {
            print("Error: \(error.localizedDescription)")
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
                print("El usuario con UID \(uid) no existe en la base de datos.")
                return nil
            }
            
            guard let data = document.data() else {
                print("El documento existe pero no tiene datos.")
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
                isDeleted: false
            )
            
        } catch {
            print("Error al obtener los datos del usuario: \(error.localizedDescription)")
            throw FirestoreError.checkUserByIDError
        }
    }
    
    /// Actualiza el nickname del usuario si no está en uso.
    ///
    /// - Parameter newNickname: El nuevo nickname que se desea asignar.
    /// - Throws: Lanza un error `FirestoreError.checkNicknameError` si ocurre un problema en la validación o actualización.
    func updateNickname(newNickname: String ) async throws {
        guard let uid = self.uid else {
            print("Error: no hay usuaria autenticado")
            return
        }
        
        do{
            let isAvalible = try await checkIfNicknameNotExists(nickname: newNickname)
            guard isAvalible else {
                print("El nickname ya esta en uso")
                return
            }
            try await database.collection("users").document(uid).updateData(["nickname": newNickname])
            print("Nickname actualizado correctamente a \(newNickname)")
        }catch{
            throw FirestoreError.checkNicknameError
        }
    }
   
    /// Agrega un usuario al chat público "global_chat". Si el chat no existe, lo crea.
    ///
    /// - Parameter userID: El identificador del usuario que se agregará al chat.
    /// - Throws: Lanza un error si la operación en Firestore falla.
    func addUserToPublicChat(userID: String) async throws {
        let chatRef = database.collection("public_chats").document("global_chat")
        
        do {
            let chatDoc = try await chatRef.getDocument()
            
            if chatDoc.exists {
                // 🔹 Si el chat ya existe, obtenemos los participantes
                var participants = chatDoc["participants"] as? [String] ?? []
                
                if !participants.contains(userID) {
                    // 🔹 Agregar usuario si no está en la lista
                    participants.append(userID)
                    try await chatRef.updateData(["participants": participants])
                    print("✅ Usuario \(userID) agregado al chat público.")
                } else {
                    print("⚠️ Usuario \(userID) ya está en el chat público.")
                }
            } else {
                // 🔹 Si el chat público NO EXISTE, lo creamos y agregamos al usuario
                let publicChatData: [String: Any] = [
                    "id": "global_chat",
                    "participants": [userID],
                    "lastMessage": "Bienvenidos al chat público!",
                    "lastMessageTimestamp": Timestamp()
                ]
                try await chatRef.setData(publicChatData)
                print("✅ Chat público creado y usuario \(userID) agregado.")
            }
        } catch {
            print("❌ Error al agregar usuario al chat público: \(error.localizedDescription)")
            throw FirestoreError.newAccountError
        }
    }

    /// Oculta la cuenta del usuario marcándola como eliminada en Firestore.
    ///
    /// - Throws: Lanza un error si no se puede actualizar el estado del usuario en Firestore.
    func setUserInvisible() async throws {
        guard let uid = self.uid else { throw FirestoreError.checkUserByIDError }
        
        do {
            try await database.collection("users").document(uid).updateData(["isDeleted": true])
            print("Cuenta marcada como eliminada (invisible)")
        } catch {
            print("Error al marcar la cuenta como invisible: \(error)")
            throw error
        }
    }
}


