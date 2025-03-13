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
    case loggedOut, hasNickname, loggedIn
}


actor GoogleService {
    var showError = false
    var errorMessage: String = ""
    var navigateHome = false
    
    /// Autentica al usuario con Google y Firebase.
    ///
    /// - Returns: `true` si la autenticación fue exitosa, `false` en caso contrario.
    /// - Throws: Lanza un error si ocurre un problema en la autenticación.
    @MainActor func authenticate() async throws -> Bool {
        
        // Obtiene el clientID de la configuración de Firebase.
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "Falta el client ID de Firebase", code: 0, userInfo: nil)
        }
        
        // Configura la instancia de Google Sign-In con el clientID de Firebase.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Obtiene el `rootViewController` para presentar la pantalla de inicio de sesión.
        guard let presentingVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }) // Filtra las escenas activas.
            .flatMap({ $0.windows })              // Obtiene las ventanas de la escena.
            .first(where: { $0.isKeyWindow })?    // Encuentra la ventana clave.
            .rootViewController else {            // Obtiene el controlador raíz.
            throw NSError(domain: "No se puede mostrar la vista de inicio de sesión de Google", code: 0, userInfo: nil)
        }
   
        // Inicia sesión con Google y obtiene la credencial para Firebase.
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { signInResult, error in
              
                // Verifica si ocurrió un error durante la autenticación de Google.
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Extrae el usuario autenticado y sus tokens de autenticación.
                guard let user = signInResult?.user,
                      let idToken = user.idToken?.tokenString else {
                    continuation.resume(throwing: NSError(domain: "Falló la autenticación", code: 0, userInfo: nil))
                    return
                }
                
                // Crea una credencial de Firebase usando el token de Google.
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                
                // Inicia sesión en Firebase con la credencial obtenida.
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
    ///
    /// Si ocurre un error al cerrar sesión, se imprime un mensaje en la consola.
    nonisolated func logout() {
        do {
            // Intenta cerrar sesión en Firebase.
            try Auth.auth().signOut()
            
        } catch {
            
            // Maneja y muestra cualquier error que ocurra al cerrar sesión.
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
