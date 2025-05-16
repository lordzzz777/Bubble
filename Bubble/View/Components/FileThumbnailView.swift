//
//  FileThumbnailView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 25/4/25.
//

import SwiftUI
@preconcurrency import QuickLookThumbnailing

struct FileThumbnailView: View {
    let fileURL: URL
    var size: CGSize = CGSize(width: 60, height: 60)
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task {
            await loadThumbnail()
        }
    }
    
    @MainActor
    private func loadThumbnail() async {
        let request = QLThumbnailGenerator.Request(fileAt: fileURL, size: size, scale: UIScreen.main.scale, representationTypes: .icon)
        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            self.thumbnailImage = thumbnail.uiImage
        } catch {
            print("Error cargando miniatura: \(error.localizedDescription)")
        }
    }
}


