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
import FirebaseFirestore
import SwiftUI

@Observable @MainActor
final class ChatFileViewModel {
    
    // MARK: - Servicios
    private let fileService = ChatFileService()
    private let publicChatService = PublicChatService()
    
    // MARK: - Estado UI
    var isUploading: Bool = false
    var isShowError: Bool = false
    var errorTitleMessage: String?
    var errorMessage: String?
    
    // MARK: - Subida de archivos
    /// Sube un archivo local a Storage y devuelve metadatos mínimos
    /// para montar el `MessageModel`.
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
    
    // MARK: - Descarga rápida
    /// Descarga un archivo desde una URL remota y lo guarda en tmp.
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
    
    // MARK: - Descarga + Persistencia local
    /// Descarga el archivo, le asigna extensión correcta y lo mueve a Documents
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
    
    // MARK: - Envío a Firestore
    /// Sube (si es necesario) y envía un mensaje de tipo `.file`
    func sendFileMessage(_ fileURL: URL,scope: ChatScope, replyingTo messageID: String? = nil) async {
        do {
            // Subida a Firebase Storage + metadata
            guard let result = try await uploadAndPrepareMessage(from: fileURL) else {return}
            
            // Crear mensaje Firestore
                let message = MessageModel(
                    id: UUID().uuidString,
                    senderUserID: Auth.auth().currentUser?.uid ?? "system",
                    content: result.url,
                    timestamp: Timestamp(date: .now),
                    type: .file,
                    replyToMessageID: messageID
                )
            
            // Seleccionar colección según el ámbito
            let ref: CollectionReference
            switch scope {
            case .public:
                ref = Firestore.firestore()
                    .collection("public_chats")
                    .document("global_chat")
                    .collection("messages")
            case .privateChat(let chatID):
                ref = Firestore.firestore()
                    .collection("chats")
                    .document(chatID)
                    .collection("messages")
            }
            
            try await ref.document(message.id).setData(message.dictionary)
            
        } catch {
            isShowError = true
            errorTitleMessage = "Error al enviar archivo"
            errorMessage = error.localizedDescription
        }
    }
    
    
    // MARK: - Validación
    /// Verifica que el archivo no exceda 25 MB.
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

    // MARK: - Borrado
    /// Elimina un archivo de Firebase Storage dado su URL completo.
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

// MARK: - Helpers UI / QuickLook
extension ChatFileViewModel {
    
    /// Devuelve solo el nombre (último pathComponent).
    func extractFileName(from urlString: String) -> String {
        URL(string: urlString)?.lastPathComponent ?? "Archivo"
    }
    
    /// Comprueba si QuickLook soporta la extensión.
    func isPreviewable(_ fileURL: URL) -> Bool {
        let previewableExtensions: [String] = ["pdf", "doc", "docx", "txt", "rtf", "png", "jpg", "jpeg", "heic", "xlsx", "csv"]
        return previewableExtensions.contains(fileURL.pathExtension.lowercased())
    }
    
    /// Selecciona un SF-Symbol apropiado según la extensión.
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
    
    /// Descarga y muestra el archivo si es compatible; si no, informa de la extensión.
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
    
    /// Abre el archivo con la app externa asociada (Compartir).
    func openFileExternally(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
