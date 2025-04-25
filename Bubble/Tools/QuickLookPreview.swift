//
//  QuickLookPreview.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 25/4/25.
//

import SwiftUI
import QuickLook


/// Representa un archivo para previsualizar con QuickLook.
class FilePreviewItem: NSObject, QLPreviewItem {
    private let fileURL: URL
    
    init(url: URL) {
        self.fileURL = url
    }
    
    // ✅ Requerido por QLPreviewItem: debe ser no opcional
    var previewItemURL: URL? {
        return fileURL
    }
    
    // (Opcional) Título visible en la barra del visor
    var previewItemTitle: String? {
        fileURL.lastPathComponent
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            FilePreviewItem(url: url)
        }
    }
}
