//
//  ChatRowSkeleton.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 30/5/25.
//

import SwiftUI

/// Vista de esqueleto para una fila de chat
struct ChatRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            AvatarSkeleton()   // 45×45 por defecto
            
            VStack(alignment: .leading, spacing: 6) {
                TextLineSkeleton(width: 140, height: 14)   // nombre
                TextLineSkeleton(width: 220)               // último mensaje
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}



#Preview {
    ChatRowSkeleton()
}
