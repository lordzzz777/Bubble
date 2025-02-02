//
//  NewAccountViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 1/31/25.
//

import Foundation
import FirebaseAuth

@Observable
class NewAccountViewModel {
    private let firebaseService: FirebaseService
    private let uid = Auth.auth().currentUser?.uid ?? ""
    var showError: Bool
    var errorMessage: String
    
    init(firebaseService: FirebaseService = FirebaseService(), showError: Bool = false, errorMessage: String = "") {
        self.firebaseService = firebaseService
        self.showError = showError
        self.errorMessage = errorMessage
    }
    

    @MainActor
    func createUser(user: UserModel) async {
        do {
            var newUser = user
            newUser.id = uid
            try await firebaseService.createUser(user: newUser)
        } catch {
            errorMessage = "Error al crear usuario"
            showError = true
            print("Ha ocurrido un error al crear el usuario: \(error)")
        }
    }
    
    @MainActor
    func checkNickNameNotExists(nickName: String) async -> Bool {
        do {
            return try await firebaseService.checkIfNicknameNotExists(nickname: nickName)
        } catch {
            showError = true
            errorMessage = "Error al verificar nickname"
            print("Error al comprobar el nombre de usuario: \(error)")
            return false
        }
    }
}
