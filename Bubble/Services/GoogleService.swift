//
//  GoogleService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 27/1/25.
//

import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

// MARK: - Enumeras los caso Login para FireBase
enum UserLoginState: Int {
    case loggedOut, loggedIn
}

@Observable
final class GoogleService {
    var showError = false
    var errorMessage: String = ""
    var navigateHome = false
    
    //MARK: Método para autenticar al usuario mediante Google Sign-In y Firebase.
    @MainActor func authenticate(completion: @escaping(Result<Bool, Error>) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(.failure(NSError(domain: "Falta el client ID de Firebase", code: 0, userInfo: nil)))
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let presentingVC = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            completion(.failure(NSError(domain: "No se puede mostrar la vista de inicio de seisón de Google", code: 0, userInfo: nil)))
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { user, error in
            if let error = error {
                print(error.localizedDescription)
                //Si el usuario cancela la acción de inciar con google se devuelve un false
                completion(.success(false))
                return
            }
            
            guard let authentication = user?.user, let idToken = user?.user.idToken else {
                completion(.failure(NSError(domain: "Falló la autenticación", code: 0, userInfo: nil)))
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString, accessToken: authentication.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(true))
                }
            }
        }
    }
    
    func logout(){
        
        do{
            try Auth.auth().signOut()
        }catch {
            print("Error signing out: %@", error.localizedDescription)
        }
    }
}
