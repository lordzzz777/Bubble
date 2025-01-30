//
//  ContentView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 24/1/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView{
            HomeView()
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
