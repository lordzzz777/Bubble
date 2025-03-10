//
//  AppleServices.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 28/1/25.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseCore
@preconcurrency import FirebaseAuth
import CryptoKit
import AuthenticationServices

@Observable
class AppleServices {

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
                print("Error: No se pudo obtener el credential")
                return
            }
            
            print("Nombre del usuario: \(credential.fullName?.description ?? "No disponible")")
            
            // Obtener el token de identidad de Apple
            guard let token = credential.identityToken else {
                print("Error: No se pudo obtener el token de identidad")
                return
            }
            
            // Convertir el token a una cadena de texto
            guard let tokenString = String(data: token, encoding: .utf8) else {
                print("Error: No se pudo convertir el token a String")
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
                    try await Auth.auth().signIn(with: firebaseCredential)
                    print("Inicio de sesión con Apple exitoso")
                } catch {
                    print("Error al iniciar sesión con Apple: \(error.localizedDescription)")
                    errorMessage = "login-apple-error"
                    showError = true
                }
            }
            
        case .failure(let failure):
            // Manejar el caso en que la autenticación con Apple falle
            print("Error al procesar la autenticación con Apple: \(failure.localizedDescription)")
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
            print("Sesión cerrada exitosamente.")
        } catch let signOutError as NSError {
            // Manejo de errores en caso de fallo al cerrar sesión.
            print("Error al cerrar sesión: \(signOutError.localizedDescription)")
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


