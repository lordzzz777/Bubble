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
    private let messageEncryptionService = MessageEncryptionService()
    private let moderationService = ModerationService()
    private let readStateService = ReadStateService()
    
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
            
            AppLogger.debug("Archivo guardado localmente.")
            return localURL
            
        } catch {
            AppLogger.error("Error al descargar y guardar archivo.")
            throw error
        }
    }
    
    func downloadAndSaveEncryptedFile(message: MessageModel, chatID: String) async throws -> URL {
        guard let url = URL(string: message.content) else { throw URLError(.badURL) }
        let (encryptedData, _) = try await URLSession.shared.data(from: url)
        let fileData = try await messageEncryptionService.decryptAttachmentData(encryptedData, message: message, chatID: chatID)
        let filename = message.attachmentFileName ?? "\(message.id).bin"
        let fileExtension = URL(fileURLWithPath: filename).pathExtension
        var tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        if !fileExtension.isEmpty {
            tempURL.appendPathExtension(fileExtension)
        }
        try fileData.write(to: tempURL, options: .atomic)
        try LocalFilePrivacyService.protectTemporaryFile(at: tempURL)
        return tempURL
    }

    func removeTemporaryPreviewFile(_ url: URL?) {
        LocalFilePrivacyService.removeProtectedTemporaryFile(at: url)
    }
    
    // MARK: - Envío a Firestore
    /// Sube (si es necesario) y envía un mensaje de tipo `.file`
    func sendFileMessage(_ fileURL: URL,scope: ChatScope, replyingTo messageID: String? = nil) async {
        do {
            switch scope {
            case .public:
                try await sendPublicFileMessage(fileURL, replyingTo: messageID)
                
            case .privateChat(let chatID):
                try await sendPrivateFileMessage(fileURL, chatID: chatID, replyingTo: messageID)
            }
            
        } catch {
            isShowError = true
            errorTitleMessage = "Error al enviar archivo"
            errorMessage = error.localizedDescription
        }
    }
    
    private func sendPublicFileMessage(_ fileURL: URL, replyingTo messageID: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let newMessageID = UUID().uuidString
        let fileData = try Data(contentsOf: fileURL)
        let participants = try await publicChatService.publicChatParticipantIDs()
        let encryptedPayload = try await messageEncryptionService.encryptAttachmentData(
            fileData,
            chatID: "global_chat",
            messageID: newMessageID,
            participantIDs: participants
        )
        let encryptedURL = try await fileService.uploadFileData(encryptedPayload.encryptedData, path: newMessageID, fileExtension: "bin")
        var message = MessageModel(
            id: newMessageID,
            senderUserID: uid,
            content: encryptedURL,
            timestamp: Timestamp(date: .now),
            type: .file,
            replyToMessageID: messageID,
            attachmentFileName: fileURL.lastPathComponent
        )
        message.encryptedMessageKeys = encryptedPayload.encryptedMessageKeys
        message.senderPublicKey = encryptedPayload.senderPublicKey
        message.encryptionVersion = encryptedPayload.encryptionVersion
        message.encryptionScheme = encryptedPayload.encryptionScheme
        
        try await publicChatService.sendPublicMessage(message)
    }
    
    private func sendPrivateFileMessage(_ fileURL: URL, chatID: String, replyingTo messageID: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await moderationService.assertCanSendPrivateMessage(chatID: chatID)
        let newMessageID = UUID().uuidString
        let fileData = try Data(contentsOf: fileURL)
        let encryptedPayload = try await messageEncryptionService.encryptAttachmentData(fileData, chatID: chatID, messageID: newMessageID)
        let encryptedURL = try await fileService.uploadFileData(encryptedPayload.encryptedData, path: newMessageID, fileExtension: "bin")
        var message = MessageModel(
            id: newMessageID,
            senderUserID: uid,
            content: encryptedURL,
            timestamp: Timestamp(date: .now),
            type: .file,
            replyToMessageID: messageID,
            attachmentFileName: fileURL.lastPathComponent
        )
        message.encryptedMessageKeys = encryptedPayload.encryptedMessageKeys
        message.senderPublicKey = encryptedPayload.senderPublicKey
        message.encryptionVersion = encryptedPayload.encryptionVersion
        message.encryptionScheme = encryptedPayload.encryptionScheme
        
        let database = Firestore.firestore()
        try await database.collection("chats")
            .document(chatID)
            .collection("messages")
            .document(message.id)
            .setData(message.dictionary)
        try await database.collection("chats").document(chatID).updateData([
            "lastMessageTimestamp": message.timestamp,
            "lastMessageSenderUserID": message.senderUserID,
            "lastMessage": "Adjunto cifrado",
            "lastMessageType": message.type.rawValue
        ])
        try await readStateService.incrementPrivateChat(chatID: chatID, senderID: message.senderUserID)
    }
    
    
    // MARK: - Validación
    /// Verifica que el archivo no exceda 25 MB.
    func validateFileSize(_ fileURL: URL) async throws {
        do {
            try await fileService.validateFileSize(fileURL)
            AppLogger.debug("Tamaño de archivo válido.")
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
            AppLogger.debug("Archivo eliminado del servidor.")
        } catch {
            isShowError = true
            errorTitleMessage = "Error al eliminar archivo"
            errorMessage = "No se pudo eliminar el archivo del servidor."
            AppLogger.error("Error al eliminar archivo.")
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
            showPreview(for: localURL, isPreviewPresented: isPreviewPresented, previewedFileURL: previewedFileURL, unsupportedExtension: unsupportedExtension)
        }catch {
            AppLogger.error("Error al abrir archivo.")
            throw error
        }
    }
    
    func previewsEncryptedFile(_ message: MessageModel, chatID: String, isPreviewPresented: Binding<Bool>, previewedFileURL: Binding< URL?>, unsupportedExtension: Binding <String?>) async throws {
        do {
            let localURL = try await downloadAndSaveEncryptedFile(message: message, chatID: chatID)
            showPreview(for: localURL, isPreviewPresented: isPreviewPresented, previewedFileURL: previewedFileURL, unsupportedExtension: unsupportedExtension)
        } catch {
            AppLogger.error("Error al abrir archivo cifrado.")
            throw error
        }
    }
    
    private func showPreview(for localURL: URL, isPreviewPresented: Binding<Bool>, previewedFileURL: Binding< URL?>, unsupportedExtension: Binding <String?>) {
        let ext = localURL.pathExtension.lowercased()
        let allowedExtensions = ["pdf", "docx", "xlsx", "pptx", "txt", "rtf"]
        
        if allowedExtensions.contains(ext){
            previewedFileURL.wrappedValue = localURL
            isPreviewPresented.wrappedValue = true
        }else {
            unsupportedExtension.wrappedValue = ext
            isPreviewPresented.wrappedValue = true
        }
    }
    
    /// Abre el archivo con la app externa asociada (Compartir).
    func openFileExternally(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
