//
//  NewAccountViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 1/31/25.
//

import Foundation
import SwiftUI
import FirebaseAuth

@Observable @MainActor
class NewAccountViewModel {
    private let firestoreService: FirestoreService
    
    var uid: String? {
        return Auth.auth().currentUser?.uid
    }

    var user: UserModel?
    var showError: Bool
    var errorTitle: String
    var errorDescription: String
    var showImageUploadError: Bool
    var isShowTemporaryAlert: Bool = false
    var temporaryTitleAlert = ""
    var temporaryMessagesAlert = ""
    
    init(firebaseService: FirestoreService = FirestoreService(), showError: Bool = false, errorTitle: String = "", errorDescription: String = "", showImageUploadError: Bool = false) {
        self.firestoreService = firebaseService
        self.showError = showError
        self.errorTitle = errorTitle
        self.errorDescription = errorDescription
        self.showImageUploadError = showImageUploadError
    }
    
    /// Crea un nuevo usuario en Firestore y lo agrega al chat público.
    ///
    /// - Parameter user: El modelo de usuario que se desea registrar.
    func createUser(user: UserModel) async {
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Error : No hay usuarios autenticados")
            return
        }
        
        do {
            var newUser = user
            newUser.id = uid
            try await firestoreService.createUser(user: newUser)
            try await firestoreService.addUserToPublicChat(userID: uid)
        } catch {
            errorTitle = "Error al crear usuario"
            errorDescription = "Hubo un error al crear el usuario. Inténtelo más tarde."
            showError = true
            print("Ha ocurrido un error al crear el usuario: \(error)")
        }
    }
    
    /// Verifica si un nickname ya está en uso en Firestore.
    ///
    /// - Parameter nickName: El nickname que se desea verificar.
    /// - Returns: `true` si el nickname no existe en la base de datos (está disponible),
    ///  `false` si ya está en uso o si ocurre un error.
    func checkNickNameNotExists(nickName: String) async -> Bool {
        do {
            return try await firestoreService.checkIfNicknameNotExists(nickname: nickName)
        } catch {
            showError = true
            errorTitle = "Error al verificar nickname"
            errorDescription = "Hubo un error al comprobar el nickname. Inténtelo más tarde."
            print("Error al comprobar el nombre de usuario: \(error)")
            return false
        }
    }
    
    /// Guarda una imagen en el servidor a través del servicio Firestore.
    ///
    /// - Parameter image: La imagen `UIImage` que se desea subir.
    func saveImage(image: UIImage) async {
        do {
            try await firestoreService.saveImage(image: image)
        } catch {
            errorTitle = "Error al cargar la imagen"
            errorDescription = "Hubo un error al subir la imagen al servidor. Inténtelo más tarde."
            showError = true
            showImageUploadError = true
        }
    }
    
    /// Carga los datos del usuario desde Firestore y los almacena en la variable `user`.
    ///
    /// - Nota: Si no se encuentra el usuario, se muestra un mensaje de error en la UI.
    func loadUserData() async{
        do{
            let data = try await firestoreService.getUserData()
            guard let getUser = data else{ return }
            self.user = getUser
        }catch{
            errorTitle = "Error"
            errorDescription = "Usuario no encontrado"
            showError = true
        }
    }
    
    /// Actualiza el nickname del usuario en Firestore.
    ///
    /// - Parameter newNickname: El nuevo nickname que el usuario desea establecer.
    func updateNicname(newNickname: String) async{
        
        do{
            try await firestoreService.updateNickname(newNickname: newNickname)
            self.user?.nickname = newNickname
        }catch{
            showError = true
            errorTitle = "Error al verificar nickname"
            errorDescription = "Hubo un error al comprobar el nickname. Inténtelo más tarde."
            print("Error al comprobar el nombre de usuario: \(error)")
        }
    }
    
    /// Muestra una alerta personalizada que desaparece automáticamente después de un tiempo.
    ///
    /// - Parameters:
    ///   - title: El título de la alerta.
    ///   - message: El mensaje que se mostrará en la alerta.
    ///   - seconds: Tiempo en segundos antes de que la alerta se cierre automáticamente (por defecto, 6 segundos).
    func showTemporaryAlert(title: String,  message: String, autoDissmisAfter seconds: Double = 6) async {
        temporaryMessagesAlert = message
        temporaryTitleAlert = title
        
        isShowTemporaryAlert = true
            Task{
                try await Task.sleep(for: .seconds(seconds))
                isShowTemporaryAlert = false
            }
    }
    
    /// Marca la cuenta del usuario como invisible
    func deleteUserAccount() async {
        do {
            try await firestoreService.setUserInvisible()
            print("Cuenta marcada como eliminada (invisible)")
        } catch {
            showError = true
            errorTitle = "Error"
            errorDescription = "No se pudo eliminar la cuenta"
            print("Error al eliminar la cuenta: \(error)")
        }
    }
}
