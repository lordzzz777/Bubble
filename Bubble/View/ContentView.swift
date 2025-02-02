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
            
            VStack(alignment: .center, content: {
                if isConnected {
                    HomeView()
                } else {
                    Text("¡¡Sin señal de red ... !!").font(.largeTitle.bold())
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 150).bold())
                }
            })
            .task {
                for await status in networkMonitor.connectionStatuses() {
                    isConnected = status
                }
            }
            
            .tabItem({
                Label("Chas", systemImage: "message.fill")
            })
            
            Text("Pantalla 2")
                .tabItem({
                    Label("", systemImage: "person.3.sequence.fill")
                })
            
            Text("Pantalla 3")
                .tabItem({
                    Label("", systemImage: "gear")
                })
        }
    }
}


#Preview {
    ContentView()
}
