//
//  AppleServices.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 28/1/25.
//

import Foundation
import SwiftUI
import FirebaseCore
@preconcurrency import FirebaseAuth
import CryptoKit
import AuthenticationServices

@Observable
class AppleServices {

    private let firestoreService = FirestoreService()
    var nonce = ""
    var errorMessage: LocalizedStringKey = ""
    var showError = false
    
    /// Configura la solicitud de autenticación con Apple.
    ///
    /// - Parameter request: La solicitud de autenticación `ASAuthorizationOpenIDRequest` que se enviará a Apple.
    func continueWithAppleRequest(request: ASAuthorizationOpenIDRequest) {
        
        // Genera un nonce aleatorio para mejorar la seguridad de la autenticación.
        nonce = randomNonceString()
        
        // Especifica que se solicitarán el nombre completo y el correo electrónico del usuario.
        request.requestedScopes = [.fullName, .email]
        
        // Aplica un hash SHA-256 al nonce para mayor seguridad antes de enviarlo.
        request.nonce = sha256(nonce)
    }
        
    /// Maneja el resultado de la autenticación con Apple y procede a autenticar al usuario en Firebase.
    ///
    /// - Parameter result: El resultado de la autenticación de Apple (`ASAuthorization` o un `Error`).
    @MainActor
    func continueWithAppleCompletion(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let user):
            // Obtener las credenciales de Apple
            guard let credential = user.credential as? ASAuthorizationAppleIDCredential else {
                AppLogger.error("No se pudo obtener la credencial de Apple.")
                return
            }
            
            // Obtener el token de identidad de Apple
            guard let token = credential.identityToken else {
                AppLogger.error("No se pudo obtener el token de identidad de Apple.")
                return
            }
            
            // Convertir el token a una cadena de texto
            guard let tokenString = String(data: token, encoding: .utf8) else {
                AppLogger.error("No se pudo procesar el token de identidad de Apple.")
                return
            }
            
            // Obtener el nombre completo del usuario (puede ser `nil` si el usuario no proporciona su nombre completo)
            let fullName = credential.fullName
            
            // Generar las credenciales de Firebase usando el token de Apple
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: fullName
            )
            
            // Autenticar al usuario en Firebase con las credenciales generadas
            Task {
                do {
                    let result = try await Auth.auth().signIn(with: firebaseCredential)
                    let hasUserProfile = try await firestoreService.checkIfUserExistsByID(userID: result.user.uid)
                    UserDefaults.standard.set(
                        hasUserProfile ? UserLoginState.loggedIn.rawValue : UserLoginState.hasNickname.rawValue,
                        forKey: "LoginFlowState"
                    )
                } catch {
                    errorMessage = "No se pudo iniciar sesión con Apple. Inténtelo más tarde."
                    showError = true
                }
            }
            
        case .failure:
            // Manejar el caso en que la autenticación con Apple falle
            AppLogger.error("Error al procesar la autenticación con Apple.")
        }
    }

    /// Cierra sesión del usuario en Firebase.
    ///
    /// Si ocurre un error durante el cierre de sesión, se imprime un mensaje en la consola.
    func logout() {
        let firebaseAuth = Auth.auth()
        
        do {
            // Intenta cerrar sesión en Firebase.
            try firebaseAuth.signOut()
            AppLogger.info("Sesión cerrada.")
        } catch {
            // Manejo de errores en caso de fallo al cerrar sesión.
            AppLogger.error("Error al cerrar sesión.")
        }
    }

    /// Genera una cadena aleatoria (nonce) de la longitud especificada.
    ///
    /// - Parameter length: La longitud deseada de la cadena aleatoria (por defecto, 32 caracteres).
    /// - Returns: Una cadena aleatoria segura que se puede usar como nonce.
    /// - Note: Utiliza `SecRandomCopyBytes` para garantizar una generación segura de valores aleatorios.
    private func randomNonceString(length: Int = 32) -> String {
        // Asegura que la longitud solicitada sea mayor a 0.
        precondition(length > 0, "La longitud del nonce debe ser mayor a 0.")
        
        // Caracteres permitidos en la cadena nonce.
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            // Genera un conjunto de 16 bytes aleatorios.
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                
                // Si la generación de bytes aleatorios falla, lanza un error crítico.
                if errorCode != errSecSuccess {
                    fatalError("No se pudo generar el nonce. SecRandomCopyBytes falló con OSStatus \(errorCode).")
                }
                
                return random
            }
            
            // Convierte los bytes aleatorios en caracteres válidos del charset.
            for random in randoms {
                if remainingLength == 0 {
                    break
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }

    
    /// Genera un hash SHA-256 de una cadena de texto.
    ///
    /// - Parameter input: La cadena de entrada que se quiere hashear.
    /// - Returns: Una cadena de texto representando el hash SHA-256 en formato hexadecimal.
    private func sha256(_ input: String) -> String {
        // Convierte la cadena de entrada a datos en formato UTF-8.
        let inputData = Data(input.utf8)
        
        // Genera el hash SHA-256 a partir de los datos de entrada.
        let hashedData = SHA256.hash(data: inputData)
        
        // Convierte los bytes del hash en una representación hexadecimal.
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0) // Convierte cada byte a un string hexadecimal de dos caracteres.
        }.joined()
        
        return hashString
    }

}

