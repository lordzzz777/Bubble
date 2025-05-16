//
//  ChatFileViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 24/4/25.
//

import Foundation
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseCore
import SwiftUI

@Observable @MainActor
final class ChatFileViewModel {
    
    private let fileService = ChatFileService()
    private let publicChatService = PublicChatService()
    
    var isUploading: Bool = false
    var isShowError: Bool = false
    var errorTitleMessage: String?
    var errorMessage: String?
    
    /// Subida de archivo desde URL local y retorno del mensaje para guardar en Firestore.
    func uploadAndPrepareMessage(from fileURL: URL) async throws -> (name: String, type: String, url: String)? {
        isUploading = true
        
        defer{ isUploading = false} // se asegure que siempre se apague
        
        do{
            let downloadURL = try await fileService.upploadFile(fileURL)
            let fileName = fileURL.lastPathComponent
            let fileType =  await fileService.extractFileType(from: fileURL)
            
            return (name: fileName, type: fileType, url: downloadURL)
        }catch{
            isUploading = false
            isShowError = true
            errorTitleMessage = "Error al subir archivo"
            errorMessage = "No se ha podido subir el archivo \( error.localizedDescription)"
            return nil
        }
    }
    
    /// Descarga el archivo y lo retorna como URL local.
    func dowloadFile (from urlString: String) async -> URL? {
        do{
            return try await fileService.downloadFile(from: urlString)
        }catch{
            isShowError = true
            errorTitleMessage = "Error al descargar archivo"
            errorMessage = "No se ha podido descargar el archivo \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Descarga el archivo desde Firebase y lo guarda en el almacenamiento local del dispositivo.
    /// - Parameter remoteURL: La URL del archivo en Firebase Storage.
    /// - Returns: URL local del archivo guardado.
    func downloadAndSaveFile(from remoteURL: String) async throws -> URL {
        do {
            // 1. Descargar a ubicación temporal
            let tempURL = try await fileService.downloadFile(from: remoteURL)
            
            // 2. Extraer extensión original o usar "bin"
            let ext = URL(string: remoteURL)?.pathExtension.isEmpty == false
            ? URL(string: remoteURL)!.pathExtension
            : "bin"
            
            // 3. Generar nombre único con extensión correcta
            let filename = UUID().uuidString + "." + ext.lowercased()
            
            // 4. Guardar en Documents
            let localURL = try await fileService.saveDownloadedFileLocally(
                tempURL: tempURL,
                originalFilename: filename
            )
            
            print("Archivo guardado localmente en: \(localURL)")
            return localURL
            
        } catch {
            print("Error al descargar y guardar archivo: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Sube un archivo, crea un mensaje de tipo `.file` y lo envía al chat público.
    /// - Parameters:
    ///   - fileURL: URL local del archivo seleccionado.
    ///   - messageID: (Opcional) ID del mensaje al que se responde, si es una respuesta.
    func sendFileMessage(_ fileURL: URL, replyingTo messageID: String? = nil) async {
        do {
            if let result = try await uploadAndPrepareMessage(from: fileURL) {
                let message = MessageModel(
                    id: UUID().uuidString,
                    senderUserID: Auth.auth().currentUser?.uid ?? "system",
                    content: result.url,
                    timestamp: Timestamp(date: .now),
                    type: .file,
                    replyToMessageID: messageID
                )
                try await publicChatService.sendPublicMessage(message)
            }
        } catch {
            isShowError = true
            errorTitleMessage = "Error al enviar archivo"
            errorMessage = error.localizedDescription
        }
    }
    
    
    /// Valida que el archivo no supere el tamaño permitido.
    /// - Parameter fileURL: Ruta local del archivo a validar.
    /// - Throws: Error si el archivo supera el tamaño permitido.
    func validateFileSize(_ fileURL: URL) async throws {
        do {
            try await fileService.validateFileSize(fileURL)
            print("Tamaño de archivo válido.")
        } catch {
            isShowError = true
            errorTitleMessage = "Archivo demasiado grande"
            errorMessage = "El archivo excede el tamaño permitido. Máximo 25MB."
            throw error
        }
    }

    /// Elimina un archivo del almacenamiento en la nube (Firebase Storage).
    /// - Parameter storageURL: URL completa del archivo en Firebase Storage.
    /// - Throws: Error si no se puede eliminar.
    func deleteFileFromStorage(_ storageURL: String) async throws {
        do {
            try await fileService.deleteFileFromStorage(storageURL)
            print("Archivo eliminado correctamente del servidor.")
        } catch {
            isShowError = true
            errorTitleMessage = "Error al eliminar archivo"
            errorMessage = "No se pudo eliminar el archivo del servidor."
            print("Error al eliminar archivo: \(error.localizedDescription)")
            throw error
        }
    }
    


}


extension ChatFileViewModel {
    
    /// Retorna el nombre del archivo desde la URL
    func extractFileName(from urlString: String) -> String {
        URL(string: urlString)?.lastPathComponent ?? "Archivo"
    }
    
    /// Determina si el archivo es compatible con QuickLook (vista previa)
    func isPreviewable(_ fileURL: URL) -> Bool {
        let previewableExtensions: [String] = ["pdf", "doc", "docx", "txt", "rtf", "png", "jpg", "jpeg", "heic", "xlsx", "csv"]
        return previewableExtensions.contains(fileURL.pathExtension.lowercased())
    }
    
    /// Devuelve un ícono según el tipo de archivo
    func iconForFileType(_ path: String) -> String {
        let ext = URL(string: path)?.pathExtension.lowercased() ?? ""
        
        switch ext {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx": return "tablecells"
        case "txt": return "note.text"
        case "jpg", "jpeg", "png", "heic": return "photo"
        case "zip", "rar": return "archivebox"
        default: return "doc"
        }
    }
    
    /// Descarga y abre un archivo si su extensión es compatible, o muestra un aviso si no lo es.
    func previewsFile(_ message: String,isPreviewPresented: Binding<Bool>, previewedFileURL: Binding< URL?>, unsupportedExtension: Binding <String?>) async throws{
        do{
            let localURL = try await downloadAndSaveFile(from: message)
            let ext = localURL.pathExtension.lowercased()
            let allowedExtensions = ["pdf", "docx", "xlsx", "pptx", "txt", "rtf"]
            
            // Si el archivo es compatible, lo muestra; si no, guarda la extensión para mostrar aviso
            if allowedExtensions.contains(ext){
                previewedFileURL.wrappedValue = localURL
                isPreviewPresented.wrappedValue = true
            }else {
                unsupportedExtension.wrappedValue = ext
                isPreviewPresented.wrappedValue = true
            }
        }catch {
            print("Error al abrir archivo: \(error.localizedDescription)")
            throw error
        }
    }
    
    func openFileExternally(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
