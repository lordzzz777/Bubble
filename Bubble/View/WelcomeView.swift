//
//  WelcomeView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 27/1/25.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        
        VStack{
            // Titulo de presentación
            VStack{
                Text("Bienvenido a la")
                Text("App Bubble")
            }.font(.largeTitle.bold())
                .offset(y: 100)
            Spacer()
            VStack{
                // Componente boton editable
                ComponetButtonView(titleButtons: "Inniciar con ...", nameIcons: "apple.logo",isSystemImage: true, width: 300,height: 50, color: Color.black, actions: {
                    // ... Logica inicio con Apple
                })
                
                ComponetButtonView(titleButtons: "Iniciar con Goojle", nameIcons: "google", isSystemImage: false, width: 300, height: 50, color: .white, actions: {
                    // ... Logica inicio con Google
                })
            }.offset(y: -90)
        }
    }
}

#Preview {
    WelcomeView()
}
