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
    private let uid = Auth.auth().currentUser?.uid ?? ""
    var showError: Bool
    var errorTitle: String
    var errorDescription: String
    var showImageUploadError: Bool
    
    init(firebaseService: FirestoreService = FirestoreService(), showError: Bool = false, errorTitle: String = "", errorDescription: String = "", showImageUploadError: Bool = false) {
        self.firestoreService = firebaseService
        self.showError = showError
        self.errorTitle = errorTitle
        self.errorDescription = errorDescription
        self.showImageUploadError = showImageUploadError
    }
    
    func createUser(user: UserModel) async {
        do {
            var newUser = user
            newUser.id = uid
            try await firestoreService.createUser(user: newUser)
        } catch {
            errorTitle = "Error al crear usuario"
            errorDescription = "Hubo un error al crear el usuario. Inténtelo más tarde."
            showError = true
            print("Ha ocurrido un error al crear el usuario: \(error)")
        }
    }
    

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
}
