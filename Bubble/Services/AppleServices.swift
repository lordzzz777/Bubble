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
final class AppleServices {
    var nonce = ""
    var errorMessage: LocalizedStringKey = ""
    var showError = false
    
    func continueWithAppleRequest(request: ASAuthorizationOpenIDRequest) {
        nonce = randomNonceString()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
        
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
            
            // Obtener el token de identidad
            guard let token = credential.identityToken else {
                print("Error: No se pudo obtener el token de identidad")
                return
            }
            
            // Convertir el token en una cadena
            guard let tokenString = String(data: token, encoding: .utf8) else {
                print("Error: No se pudo convertir el token a String")
                return
            }
            
            // Obtener el nombre completo del usuario (opcional)
            let fullName = credential.fullName // Puede ser `nil` si el usuario no proporciona su nombre completo
            
            // Generar las credenciales de Firebase con fullName
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: fullName
            )
            
            // Autenticar al usuario con Firebase
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
            // Manejar el caso de error
            print("Error al procesar la autenticación con Apple: \(failure.localizedDescription)")
        }
    }


    func logout() {
        let firebaseAuth = Auth.auth()
        
        do {
            try firebaseAuth.signOut()
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
    }
        
}

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: Array<Character> =
    Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    
    while remainingLength > 0 {
        let randoms: [UInt8] = (0 ..< 16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
        }
        
        randoms.forEach { random in
            if remainingLength == 0 {
                return
            }
            
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    
    return result
}

//private func randomNonceString(length: Int = 32) -> String {
//    precondition(length > 0)
//    var randomBytes = [UInt8](repeating: 0, count: length)
//    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
//    if errorCode != errSecSuccess {
//        fatalError(
//            "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
//        )
//    }
//    
//    let charset: [Character] =
//    Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
//    
//    let nonce = randomBytes.map { byte in
//        // Pick a random character from the set, wrapping around if needed.
//        charset[Int(byte) % charset.count]
//    }
//    
//    return String(nonce)
//    }

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
    }.joined()
    
    return hashString
}
