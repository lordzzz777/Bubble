//
//  BubbleShareViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 9/6/25.
//

import CoreTransferable
import Foundation
import SwiftUI

@Observable @MainActor
final class BubbleShareViewModel {
    private let cache = FileCacheActor()
    private let messageEncryptionService = MessageEncryptionService()
    
    // Estado por Buebuja (Cada instacia se vive detras de la vista)
    var localURL: URL? = nil
    var isWorking = false
    var isShowError: Bool = false
    var errorTitleMessage: String? = nil
    var errorMessage: String? = nil
    
    
    /// Pre-descarga si es necesario. Se llama desde `.task` en la burbuja.
    func prepare(for message: MessageModel, chatID: String? = nil) async {
        guard message.type == .file || message.type == .audio || message.type == .image else { return }
        guard let url = URL(string: message.content) else { return }
        
        isWorking = true
        defer { isWorking = false }
        
        do {
            if message.encryptionVersion != nil, let chatID {
                let (encryptedData, _) = try await URLSession.shared.data(from: url)
                let decryptedData = try await messageEncryptionService.decryptAttachmentData(encryptedData, message: message, chatID: chatID)
                let localURL = temporaryShareURL(for: message)
                try decryptedData.write(to: localURL)
                try LocalFilePrivacyService.protectTemporaryFile(at: localURL)
                self.localURL = localURL
            } else if message.type == .file || message.type == .audio {
                localURL = try await cache.localURL(for: url)
            }
        } catch {
            isShowError = true
            errorTitleMessage = "No se puede descargar"
            errorMessage = "No se pudo preparar para compartir."
        }
    }
    
    /// Devuelve el `Transferable` listo para ShareLink o nil si aún no está.
    func shareItem(for message: MessageModel) -> (any Transferable)? {
        switch message.type {
        case .text:
            return message.content
        case .image:
            return message.encryptionVersion == nil ? URL(string: message.content) : localURL
        case .file, .audio:
            return localURL
        default:
            return nil
        }
    }
    
    private func temporaryShareURL(for message: MessageModel) -> URL {
        let filename: String
        switch message.type {
        case .image:
            filename = "\(message.id).png"
        case .audio:
            filename = "\(message.id).m4a"
        case .file:
            filename = message.attachmentFileName ?? "\(message.id).bin"
        default:
            filename = "\(message.id).bin"
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
    
    /// Opcional: icono SF Symbol según extensión (para SharePreview).
    func icon(for url: URL) -> String {
        switch url.pathExtension.lowercased(){
        case "pdf": 
            return "doc.richtext"
        case "mp3","m4a": 
            return "waveform"
        case "jpg","png": 
            return "photo"
        default:
            return "dic"
        }
    }
}
