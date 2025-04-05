//
//  ComponetImageKFImage.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 4/4/25.
//

import SwiftUI
import Kingfisher

@MainActor
struct ComponetImageKFImage: View {
    let url: URL
    var body: some View {
        KFImage(url)
            .placeholder{
                ProgressView()
            }
            .resizable()
            .scaledToFill()
            .clipShape(Circle())
            .frame(width: 170, height: 170)
    }
}

