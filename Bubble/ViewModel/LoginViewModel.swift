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
import FirebaseFirestore

@Observable @MainActor
class LoginViewModel {
    private let googleService = GoogleService()
    private let firestoreService = FirestoreService()
    private let uid = Auth.auth().currentUser?.uid
    
    var errorTitle: String = ""
    var errorMessage: String = ""
    var showError: Bool = false
    
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

    
    /// Inicia sesión con Google
    func signInWithGoogle() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error: No hay usuario autenticado.")
            return
        }
        
        Task {
            do {
                // Verivicar si el usuario exite
                let user = try await firestoreService.checkIfUserExistsByID(userID: userID)
                let success = try await googleService.authenticate()// autentica al usuario
                
                if success == true {
                    if user{
                        loginFlowState = .loggedIn
                    }else{
                        loginFlowState = .hasNickname
                    }
                    
                }else {
                    print("Estoy dentro del else de la funcion signInWithGoogle()")
                }
                
            } catch {
                print(error.localizedDescription)
                errorTitle = "Error al iniciar con Google"
                errorMessage = "Ocurrio un error intentelo mas tarde"
                showError = true
            }
        }
    }
    
    /// Cierra sesión en Firebase y actualiza el estado en la UI.
    func logout() {
        googleService.logout()
        loginFlowState = .loggedOut
    }
    
    /// Cierra sesión y borra datos de `UserDefaults`
    func logoutUser() {
        Task {
            do {
                //Detener todos los listeners de Firestore antes de cerrar sesión
                try await Firestore.firestore().terminate()
                try await Firestore.firestore().clearPersistence()
                print("Listeners de Firestore detenidos")
                
                await MainActor.run {
                    UserDefaults.standard.removeObject(forKey: "LoginFlowState")
                    loginFlowState = .loggedOut
                }
                
                print("Sesión cerrada y Google Sign-In revocado")
            } catch let error as NSError {
                print("Error al cerrar sesión: \(error), \(error.userInfo)")
                errorTitle = "Error al cerrar sesión"
                errorMessage = "Ocurrio un error intentelo mas tarde"
                showError = true
            }
        }
    }
}
