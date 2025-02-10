//
//  LoginViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 28/1/25.
//

import Foundation
import SwiftUI
import Observation
import FirebaseAuth

@Observable @MainActor
class LoginViewModel {
    private let googleService = GoogleService()
    private let firestoreService = FirestoreService()
    private let uid = Auth.auth().currentUser?.uid
    
    var showError: Bool = false
    var errorTitle: String = ""
    var errorDescription: String = ""
    var showImageUploadError: Bool = false
    
    var isAuthenticated = false
    var errorMessage: String = ""
    
    /// Estado de autenticación almacenado en `UserDefaults`
    var loginFlowState: UserLoginState{
        get{
            let staredValue = UserDefaults.standard.integer(forKey: "LoginFlowState")
            return UserLoginState(rawValue: staredValue) ?? .loggedOut
        }
        
        set{
            UserDefaults.standard.set(newValue.rawValue, forKey: "LoginFlowState")
        }
    }

    
    /// Autentica al usuario con Google y actualiza el estado en la UI.
    func signInWithGoogle() {
        Task {
            do {
                let success = try await googleService.authenticate()
                
                if success == true {
                    loginFlowState = .loggedIn
                }else {
                    await checkIfUserHasNickname()
                }
                
            } catch {
               // showError = true
                print(error.localizedDescription)
                errorMessage = "Ocurrio un error intentelo mas tarde"
            }
        }
    }
    
    /// Cierra sesión en Firebase y actualiza el estado en la UI.
    func logout() {
        googleService.logout()
        loginFlowState = .loggedOut
    }
    
    func checkIfUserHasNickname() async {
        guard let userID = uid else {
             loginFlowState = .loggedOut
            return
        }
        
        do {
            let hasNickname = try await firestoreService.checkIfNicknameNotExists(nickname: userID)
            if hasNickname  == true{
                loginFlowState = .loggedIn
                print("He entrado aqui 1º.......")
            }else {
                loginFlowState = .hasNickname
                print("He entrado aqui 2º.......")
            }
        } catch {
            print("Error al verificar el nickname: \(error.localizedDescription)")
            logoutUser()
        }
    }
    
    /// 🔹 Cierra sesión y borra datos de `UserDefaults`
    func logoutUser() {
        do {
            try Auth.auth().signOut() // 🔹 Asegura que se ejecute sin problemas en el hilo correcto
            print("✅ Usuario cerró sesión correctamente")
        } catch {
            print("🔴 Error al cerrar sesión: \(error.localizedDescription)")
            return
        }
        
        // 🔹 Asegurar que `loginFlowState` se actualice en el hilo principal
        Task { @MainActor in
           UserDefaults.standard.removeObject(forKey: "LoginFlowState")
            loginFlowState = .loggedOut
            print("✅ Estado de sesión actualizado a 'loggedOut'")
        }
    }

}
