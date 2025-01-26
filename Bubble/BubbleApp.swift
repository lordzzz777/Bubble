//
//  BubbleApp.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 24/1/25.
//

import SwiftUI
import FirebaseCore

class AppDlegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct BubbleApp: App {
    
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDlegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            NavigationStack{
                ContentView()
            }
        }
    }
}
