//
//  Shimmer.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 30/5/25.
//

import SwiftUI

// Modificador que crea un gradiente móvil
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -150    // arranca fuera de la vista
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    phase = 350                   // desplázalo hasta cubrir la vista
                }
            }
    }
}

// Extensión con `@ViewBuilder`
extension View {
    /// Aplica shimmer sólo si `active` es `true`
    @ViewBuilder
    func shimmering(active: Bool = true) -> some View {
        if active {
            self.modifier(Shimmer())
        } else {
            self
        }
    }
}

