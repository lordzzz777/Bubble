//
//  ContentView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 24/1/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isConnected: Bool = false
    private let networkMonitor = NetworkMonitor()
    
    var body: some View {
        TabView{
            ChatsView()
                .tabItem({
                    Label("Chats", systemImage: "message.fill")
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
    }
}


#Preview {
    ContentView()
}
