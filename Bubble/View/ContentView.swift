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
    @State private var publicChatViewModel = PublicChatViewModel()
    @State private var previousPhase: ScenePhase = .inactive
    @State private var selectedTab: Int = 0
    @State private var badgeViewModel = NotificationBadgeViewModel()

    
    private let networkMonitor = NetworkMonitor()
    private let messageEncryptionService = MessageEncryptionService()
    
    @State private var isShowAlert = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatsView()
                .tabItem({
                    Label("Chats", systemImage: "message.fill")
                }).tag(0)
                .badge(badgeViewModel.chatCount)
            
            PublicChatView()
               
                .tabItem({
                    Label("Publico", systemImage: "cup.and.saucer.fill")
                }).tag(1)
                .badge(publicChatViewModel.replyNotificationsCount)
            
            CommunitiesView()
                .tabItem({
                    Label("Comunidades", systemImage: "person.3.sequence.fill")
                }).tag(2)
                .badge(badgeViewModel.communityCount)
            
            SettingView()
                .tabItem({
                    Label("Ajustes", systemImage: "gear")
                }).tag(3)
        }
        .environment(publicChatViewModel)
        .task { badgeViewModel.start() }
        .onDisappear { badgeViewModel.stop() }
        .onChange(of: publicChatViewModel.replyNotificationsCount) { _, count in
            badgeViewModel.updatePublicCount(count)
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
            previousPhase = newPhase
        }
        .onAppear{
            publicChatViewModel.isPublicChatVisible = true
            Task{
                try? await messageEncryptionService.ensureCurrentUserPublicKeyIsPublished()
                await publicChatViewModel.fetchVisibleUsers()
                publicChatViewModel.fetchPublicChatMessages()
                await publicChatViewModel.resetReplyNotificationsIfNeeded()
                
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
        .onChange(of: selectedTab) { newTab, _ in
            if newTab == 1 { // Tab de "Publico"
                publicChatViewModel.replyNotificationsCount = 0
            }
        }
        .alert("Error de conexion ⚠️",
               isPresented: $isShowAlert,
               actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            
            Text("No hay conexion wifi")
        })
        .alert("No se pudieron actualizar los pendientes", isPresented: $badgeViewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(badgeViewModel.errorMessage)
        }
    }
}


#Preview {
    ContentView()
}
