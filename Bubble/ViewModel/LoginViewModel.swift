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

    
    /// Inicia sesión con Google
    func signInWithGoogle() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error: No hay usuario autenticado.")
            return
        }
        
        Task {
            do {
                // Verivicar si el usuario exite y si tiene nickname
                let hasNickname = try await firestoreService.checkIfNicknameNotExists(nickname: userID)
                //let userID = try await firestoreService.checkIfUserExistsByID(userID: userID)
                
                // autentica al usuario
                let success = try await googleService.authenticate()
                
                if success == true {
                    if hasNickname{
                        loginFlowState = .hasNickname
                    }else{
                        loginFlowState = .loggedIn
                    }
                    
                }else {
                    print("Estoy dentro del else de la funcion signInWithGoogle()")
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
    
    // Verifica si el usuario tiene un apodo registrado en la base de datos.
    func checkIfUserHasNickname() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error: No hay usuario autenticado.")
            return
        }
        
        do {
            let hasNickname = try await firestoreService.checkIfNicknameNotExists(nickname: userID)
            
            await MainActor.run {
                if hasNickname {
                    loginFlowState = .loggedIn //Usuario ya registrado → Ir a Chats
                } else {
                    loginFlowState = .hasNickname //Usuario nuevo → Ir a Nueva Cuenta
                }
            }
            
        } catch {
            print("Error al verificar el nickname: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "No se pudo verificar tu cuenta. Inténtalo más tarde."
                showError = true
            }
        }
    }
    
    /// Cierra sesión y borra datos de `UserDefaults`
    @MainActor
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
            }
        }
    }
}
