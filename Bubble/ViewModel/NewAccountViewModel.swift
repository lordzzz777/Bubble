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
    var errorMessage: String
    var showImageUploadError: Bool = false
    
    init(firebaseService: FirestoreService = FirestoreService(), showError: Bool = false, errorMessage: String = "") {
        self.firestoreService = firebaseService
        self.showError = showError
        self.errorMessage = errorMessage
    }
    
    func createUser(user: UserModel) async {
        do {
            var newUser = user
            newUser.id = uid
            try await firestoreService.createUser(user: newUser)
        } catch {
            errorMessage = "Error al crear usuario"
            showError = true
            print("Ha ocurrido un error al crear el usuario: \(error)")
        }
    }
    

    func checkNickNameNotExists(nickName: String) async -> Bool {
        do {
            return try await firestoreService.checkIfNicknameNotExists(nickname: nickName)
        } catch {
            showError = true
            errorMessage = "Error al verificar nickname"
            print("Error al comprobar el nombre de usuario: \(error)")
            return false
        }
    }
    

    func saveImage(image: UIImage) async {
        do {
            try await firestoreService.saveImage(image: image)
        } catch {
            errorMessage = "Error al cargar la imagen en la base de datos"
            showError = true
            showImageUploadError = true
        }
    }
}
