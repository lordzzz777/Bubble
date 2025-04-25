//
//  FileViewerView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 25/4/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct FileViewerView: View {
    let fileURL: URL
    
    var body: some View {
        VStack {
            switch fileURL.pathExtension.lowercased() {
            case "txt":
                textFileView (fileURL: fileURL)
            case "pdf":
                PDFKitView(fileURL: fileURL)
            case "doc", "docx":
                wordPlaceholderView() // de momento solo muestra un playholder
            default:
                fsupportedFileView(fileExtension: fileURL.pathExtension)
            }
        }
        .navigationTitle(fileURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Muesta LOS ARCHIVOS TXT ...
    @ViewBuilder
    func textFileView (fileURL: URL) -> some View {
        var content: String = "Cargando..."
        ScrollView {
            Text(content)
                .padding()
                .monospaced()
        }
        .onAppear {
            do {
                content = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                content = "No se pudo leer el archivo de texto."
            }
        }
    }
    
    // Muestra PlayHolder de un archivo doc, docx
    @ViewBuilder
    func wordPlaceholderView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .resizable()
                .frame(width: 60, height: 70)
                .foregroundColor(.blue)
            Text("Vista previa no disponible para documentos Word.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    
    @ViewBuilder
    func fsupportedFileView(fileExtension: String) -> some View{
        VStack(spacing: 20) {
            Image(systemName: "doc.questionmark")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            Text("Vista previa no disponible")
                .font(.title3.bold())
            
            Text("No se puede previsualizar archivos .\(fileExtension.lowercased())")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
}

// Muestar los archivos PDF
struct PDFKitView: UIViewRepresentable {
    let fileURL: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: fileURL)
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
