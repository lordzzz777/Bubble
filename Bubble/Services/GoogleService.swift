//
//  GoogleService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 27/1/25.
//

import Foundation
import Firebase
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

// MARK: - Enumeras los caso Login para FireBase
enum UserLoginState: Int {
    case loggedOut, loggedIn, hasNickname
}


actor GoogleService {
    var showError = false
    var errorMessage: String = ""
    var navigateHome = false
    
    /// Autentica al usuario con Google y Firebase.
    @MainActor
    func authenticate() async throws -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "Falta el client ID de Firebase", code: 0, userInfo: nil)
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Obtener la rootViewController directamente (sin usar MainActor.run)
        guard let presentingVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            throw NSError(domain: "No se puede mostrar la vista de inicio de sesión de Google", code: 0, userInfo: nil)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { signInResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let user = signInResult?.user,
                      let idToken = user.idToken?.tokenString else {
                    continuation.resume(throwing: NSError(domain: "Falló la autenticación", code: 0, userInfo: nil))
                    return
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                
                Auth.auth().signIn(with: credential) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: true)
                    }
                }
            }
        }
    }
    
    /// Cierra sesión en Firebase.
    nonisolated func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
