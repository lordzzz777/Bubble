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
final class LoginViewModel {
    private let googleService = GoogleService()
    private let firestoreService = FirestoreService()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    var errorTitle: String = ""
    var errorMessage: String = ""
    var showError: Bool = false
    
    /// Estado de autenticación almacenado en `UserDefaults`.
    ///
    /// - Se utiliza para persistir el estado de inicio de sesión del usuario entre sesiones.
    /// - Si no se encuentra un valor válido en `UserDefaults`, se devuelve `.loggedOut`.
    var loginFlowState: UserLoginState{
        get{
            
            // Obtiene el valor almacenado en `UserDefaults` con la clave "LoginFlowState".
            let staredValue = UserDefaults.standard.integer(forKey: "LoginFlowState")
            
            // Convierte el valor almacenado a `UserLoginState`, o devuelve `.loggedOut` si no es válido.
            return UserLoginState(rawValue: staredValue) ?? .loggedOut
        }
        
        set{
            UserDefaults.standard.set(newValue.rawValue, forKey: "LoginFlowState")
        }
    }

    /// Inicia sesión con Google
    func signInWithGoogle() {        
        Task {
            do {
                // Verivicar si el usuario exite
                let user = try await firestoreService.checkIfUserExistsByID(userID: uid)
                let success = try await googleService.authenticate()// autentica al usuario
                
                if success == true {
                    if user{
                        loginFlowState = .loggedIn
                    }else{
                        loginFlowState = .hasNickname
                    }
                    
                }else {
                    AppLogger.debug("Continuando flujo de inicio con Google.")
                }
                
            } catch {
                AppLogger.error("Error en inicio de sesión con Google.")
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
    
    /// Cierra sesión del usuario y borra datos almacenados en `UserDefaults`.
    ///
    /// - Nota: Detiene los listeners de Firestore y limpia la persistencia antes de cerrar sesión.
    func logoutUser() {
        Task {
            do {
                //Detener todos los listeners de Firestore antes de cerrar sesión
                try await Firestore.firestore().terminate()
                try await Firestore.firestore().clearPersistence()
                AppLogger.debug("Listeners de Firestore detenidos.")
                
                await MainActor.run {
                    UserDefaults.standard.removeObject(forKey: "LoginFlowState")
                    loginFlowState = .loggedOut
                }
                
                AppLogger.info("Sesión cerrada y Google Sign-In revocado.")
            } catch {
                AppLogger.error("Error al cerrar sesión.")
                errorTitle = "Error al cerrar sesión"
                errorMessage = "Ocurrio un error intentelo mas tarde"
                showError = true
            }
        }
    }
}
