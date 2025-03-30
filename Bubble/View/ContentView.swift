//
//  ContentView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 24/1/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var userViewModel = UserViewModel()
    @State private var previousPhase: ScenePhase = .inactive
    
    private let networkMonitor = NetworkMonitor()
    
    @State private var isShowAlert = false
    
    var body: some View {
        TabView{
            ChatsView()
                .tabItem({
                    Label("Chats", systemImage: "message.fill")
                })
            
            PublicChatView()
                .tabItem({
                    Label("Publico", systemImage: "cup.and.saucer.fill")
                })
            
            Text("Pantalla 2")
                .tabItem({
                    Label("Comunidades", systemImage: "person.3.sequence.fill")
                })
            
            SettingView()
                .tabItem({
                    Label("Ajustes", systemImage: "gear")
                })
        }
        .onChange(of: scenePhase) { newPhase,_ in
            guard newPhase != previousPhase else {return}
            
            switch newPhase {
            case.active:
                Task {
                    await userViewModel.updateUserStatus(online: true)
                }
            case .inactive, .background:
                Task {
                    await userViewModel.updateUserStatus(online: false)
                    await userViewModel.storeLastSeen()
                }
            @unknown default:
                break
            }
//            if newPhase == .active && previousPhase != .active {
//                Task {
//                    await userViewModel.updateUserStatus(online: true)
//                }
//            } else if (newPhase == .inactive || newPhase == .background) && previousPhase != newPhase {
//                Task {
//                    await userViewModel.updateUserStatus(online: false)
//                    await userViewModel.storeLastSeen()
//                }
//            }
            
            previousPhase = newPhase
        }
        .onAppear{
            
            Task{
                if scenePhase == .active {
                    await userViewModel.updateUserStatus(online: true)
                }else{
                    await userViewModel.updateUserStatus(online: false)
                }
                 userViewModel.startMonitoringUserStatus()
                for await stutus in networkMonitor.connectionStatuses(){
                    isShowAlert = !stutus
                }
            }
        }
        .alert("Error de conexion ⚠️",
               isPresented: $isShowAlert,
               actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            
            Text("No hay conexion wifi")
        })
    }
}


#Preview {
    ContentView()
}
