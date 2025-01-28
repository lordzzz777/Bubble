//
//  WelcomeView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 27/1/25.
//

import SwiftUI
import _AuthenticationServices_SwiftUI

struct WelcomeView: View {
    @State private var loginViewModel = LoginViewModel()
    @State private var appleServices = AppleServices()
    @State private var isSignInWithGoogleButtonPressed: Bool = false
    @AppStorage("LoginFlowState") private var loginFlowState = UserLoginState.loggedOut
    
    var body: some View {
        ZStack {
            switch loginFlowState {
            case .loggedOut:
                autenticationView
            case .loggedIn:
                ContentView()
            }
        }
    }
    
    var autenticationView: some View {
        VStack{
            // Titulo de presentación
            VStack{
                Text("Bienvenido a la")
                Text("App Bubble")
            }.font(.largeTitle.bold())
                .offset(y: 100)
            Spacer()
            VStack{
                
                SignInWithAppleButton(.signIn) { request in
                    appleServices.continueWithAppleRequest(request: request)
                } onCompletion: { result in
                    appleServices.continueWithAppleCompletion(result: result)
                } .background{
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        
                }.frame(width: 300, height: 50).padding()
                
                ComponetButtonView(titleButtons: "Iniciar con Goojle", nameIcons: "google", isSystemImage: false, width: 300, height: 45, color: .white, actions: {
                    // ... Logica inicio con Google
                    
                    isSignInWithGoogleButtonPressed = true
                    
                    loginViewModel.signInWithGoogle { success in
                        if success {
                            loginFlowState = .loggedIn
                        } else {
                            loginFlowState = .loggedOut
                            isSignInWithGoogleButtonPressed = false
                        }
                    }
                    
                
                })
            }.offset(y: -90)
                .alert("Error al iniciar con Google", isPresented: $loginViewModel.showError) {
                    Button("Ok", role: .cancel) { }
                } message: {
                    Text(loginViewModel.errorMessage)
                }
        }
    }
}

#Preview {
    WelcomeView()
}
