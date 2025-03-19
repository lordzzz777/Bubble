//
//  ContentView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 24/1/25.
//

import SwiftUI

struct ContentView: View {
    
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
                    Label("Chat Café", systemImage: "cup.and.saucer.fill")
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
        .onAppear{
            Task{
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
