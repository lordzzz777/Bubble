//
//  AvatarSkeleton.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 30/5/25.
//

import SwiftUI

struct AvatarSkeleton: View {
    var size: CGFloat = 45
    var body: some View {
        Circle()
            .fill(.gray.opacity(0.3))
            .frame(width: size, height: size)
            .redacted(reason: .placeholder)
            .shimmering()
    }
}

struct TextLineSkeleton: View {
    var width: CGFloat
    var height: CGFloat = 12
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.gray.opacity(0.3))
            .frame(width: width, height: height)
            .redacted(reason: .placeholder)
            .shimmering()
    }
}


#Preview {
    AvatarSkeleton()
}
