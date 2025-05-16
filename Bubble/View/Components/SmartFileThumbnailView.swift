//
//  SmartFileThumbnailView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 26/4/25.
//

import SwiftUI
@preconcurrency import QuickLookThumbnailing

struct SmartFileThumbnailView: View {
    let fileURL: URL
    var size: CGSize = CGSize(width: 50, height: 50)
    
    @State private var thumbnailImage: UIImage?
    @State private var failedToGenerate = false
    
    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failedToGenerate {
                Image(systemName: symbolForExtension(fileURL.pathExtension))
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.purple)
                    .padding(10)
            } else {
                ProgressView()
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
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
            print("⚠️ Miniatura no soportada para: \(fileURL.lastPathComponent)")
            self.failedToGenerate = true
        }
    }
    
    private func symbolForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "ppt", "pptx": return "chart.bar.doc.horizontal"
        case "xls", "xlsx": return "tablecells"
        case "txt": return "note.text"
        case "zip", "rar": return "archivebox"
        case "mp3", "wav": return "waveform"
        case "mp4", "mov": return "video"
        case "jpg", "jpeg", "png", "gif": return "photo"
        default: return "doc"
        }
    }
}
