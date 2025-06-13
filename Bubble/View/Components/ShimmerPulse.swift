//
//  ShimmerPulse.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 13/6/25.
//

import SwiftUI


// MARK: - Shimmer + Pulse
struct ShimmerPulse: ViewModifier {
    @State private var phase: CGFloat = 0          // para el brillo móvil
    @State private var pulse = false               // para el “latido”
    
    func body(content: Content) -> some View {
        content
        //Pulso sutil
            .scaleEffect(pulse ? 1.03 : 1)
            .opacity(pulse ? 1 : 0.85)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                       value: pulse)
        //Shimmer deslizante
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.4), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)                 // desliza el degradado
                .blendMode(.plusLighter)
                .mask(content)                    // se aplica solo al texto
            }
            .onAppear {
                pulse = true                      // inicia el pulso
                
                // anima el desplazamiento infinito del brillo
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 200                   // mueve ~200 pt; ajusta a gusto
                }
            }
    }
}

// acceso rápido
extension View {
    func shimmerPulse() -> some View { modifier(ShimmerPulse()) }
}

