//
//  BubbleApp.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 24/1/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck

class AppDlegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
#if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
#endif
        return true
    }
    

}

@main
struct BubbleApp: App {
    
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDlegate.self) var delegate
    @AppStorage("LoginFlowState") private var loginFlowState = UserLoginState.loggedOut
    
    
    var body: some Scene {
        WindowGroup {
            NavigationStack{
                switch loginFlowState {
                case .loggedOut:
                    WelcomeView()
                    
                case .loggedIn:
                    NewAccountView()
                    
                case .hasNickname:
                    ContentView()
                    
                }
            }
        }
    }
}
