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
   
    var uid: String? {
        guard let user = Auth.auth().currentUser else {
            print("Intento de acceder a Firebase sin usuario autenticado.")
            return nil
        }
        return user.uid
    }
    
    func createUser(user: UserModel) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Error : No hay usuarios autenticados")
            return
        }
        
        do {
            let document = try await database.collection("users").document(uid).getDocument()
            
            if let data = document.data(), let isDeleted = data["isDeleted"] as? Bool, isDeleted {
                // 🔄 Si el usuario estaba marcado como eliminado, lo reactivamos
                try await database.collection("users").document(uid).updateData([
                    "isDeleted": false,
                    "nickname": user.nickname,
                    "lastConnectionTimeStamp": Timestamp(),
                    "isOnline": true
                ])
                print("✅ Cuenta reactivada para UID: \(uid)")
            } else {
                // 🛠️ Manteniendo la lógica existente sin cambios
                if try await checkIfUserExistsByID(userID: uid) {
                    let newUserData: [String: Any] = ["nickname": user.nickname]
                    try await database.collection("users").document(uid).updateData(newUserData)
                } else {
                    var userData = user.dictionary
                    userData["isDeleted"] = false // Asegurar que la cuenta nueva no esté eliminada
                    try await database.collection("users").document(uid).setData(userData)
                }
            }
        } catch {
            throw FirestoreError.newAccountError
        }
    }

//    func createUser(user: UserModel) async throws {
//        guard let uid = Auth.auth().currentUser?.uid else {
//            print("Error : No hay usuarios autenticados")
//            return
//        }
//        
//        do {
//            if try await checkIfUserExistsByID(userID: uid ) {
//                let newUserData: [String: Any] = ["nickname": user.nickname]
//                try await database.collection("users").document(uid).updateData(newUserData)
//            } else {
//                try await database.collection("users").document(uid).setData(user.dictionary)
//            }
//        } catch {
//            throw FirestoreError.newAccountError
//        }
//    }
    
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
    
    /// Obtiene los datos del usuario autenticado
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
    
    /// Actualizar el nicname del usuario si no esta en uso
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
    
    /// Esta funcion oculta la cuenta del usuario
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


