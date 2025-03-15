//
//  BubbleApp.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 24/1/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import GoogleSignIn

@main
struct BubbleApp: App {
    
    @AppStorage("LoginFlowState") private var loginFlowState = UserLoginState.loggedOut
    
    init() {
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        disableGRPCLogging()
#if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
#endif
        
    }
    
    var body: some Scene {
        WindowGroup {
            switch loginFlowState {
            case .loggedOut:
                WelcomeView()
                    .onOpenURL { url in
                        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
                            GIDSignIn.sharedInstance.handle(url)
                        }
                    }
                    .id(loginFlowState.rawValue)
                
            case .hasNickname:
                NewAccountView()
                
            case .loggedIn:
                ContentView()
                
            }        }
    }
    
    /// Desactiva logs de `gRPC` en Firebase
    private func disableGRPCLogging() {
        setenv("GRPC_VERBOSITY", "ERROR", 1) // Solo mostrará errores críticos
        setenv("GRPC_TRACE", "", 1) // No mostrará trazas internas de gRPC
    }
}
