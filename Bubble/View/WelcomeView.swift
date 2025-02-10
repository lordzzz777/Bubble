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
            switch loginViewModel.loginFlowState {
            case .loggedOut:
                autenticationView
            case .loggedIn:
                NewAccountView()// Vista principal de la app
            case .hasNickname:
                ContentView() // Vista para configurar el perfil
                
            }
            
        }                .animation(.easeInOut, value: loginViewModel.loginFlowState)
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
                    
                }                .background{
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.primary, lineWidth: 2)
                        .fill(.white)
                    
                    
                    
                }.frame(width: 300, height: 50).padding()
                
                Button(action: {
                    Task {
                        loginViewModel.signInWithGoogle()
                    }
                }, label: {
                    Image("google")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    Text("Sing in with Goojle").font(.title3.bold())
                        .foregroundStyle(.black)
                })
                .background{
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.primary, lineWidth: 2)
                        .fill(.white)
                        .frame(width: 300, height: 45)
                    
                    
                }.padding()
                
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
