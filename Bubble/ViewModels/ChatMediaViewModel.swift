//
//  ChatMediaViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 7/4/25.
//

import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import SwiftUI
import AVFoundation

enum ChatScope{
    case `public`, privateChat(String)
}

@Observable @MainActor
final class ChatMediaViewModel{
    
    // MARK: - Servicios auxiliares
    private let chatMediaService = ChatMediaService()
    private let chatAudioService = ChatAudioService()
    private let chatPublicService = PublicChatService()
    private let messageEncryptionService = MessageEncryptionService()
    private let moderationService = ModerationService()
    private let readStateService = ReadStateService()
   
    // MARK: - Estado de errores (Bindable en la UI si lo deseas)
    var messages: [MessageModel] = []
    var showError: Bool = false
    var errorTitle: String = ""
    var errorMessage: String = ""
    
    // MARK: - Imagen desde el Photo Picker
    /// Saca la imagen del picker, la comprime, la sube y crea el mensaje.
    func sendImageFromPicker(_ pickerItem: PhotosPickerItem?, scope: ChatScope) async {
        do {
            // 1. Obtener imagen seleccionada
            let image = try await chatMediaService.pikerImage(from: pickerItem)
            
            // 2. Comprimir a PNG
            guard let imageData = await chatMediaService.compressImage(image) else {
                throw NSError(domain: "Error al comprimir la imagen", code: 0)
            }
            
            switch scope {
            case .public:
                try await sendPublicImageMessage(imageData: imageData)
            case .privateChat(let chatID):
                try await sendPrivateImageMessage(imageData: imageData, chatID: chatID)
            }
        } catch {
            errorTitle   = "Error al enviar imagen"
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Imagen desde la cámara / Uso genérico
    /// Crea y guarda un `MessageModel` de tipo `.image` en la colección adecuada.
    /// - Parameters:
    ///   - url: URL pública devuelta por Firebase Storage.
    ///   - scope: Chat destino (`.public` o `.privateChat(id)`).
    private func sendImageMessage(with url: String, scope: ChatScope) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let message = MessageModel(
            id:           UUID().uuidString,
            senderUserID: uid,
            content:      url,
            timestamp:    Timestamp(date: .now),
            type:         .image
        )
        
        let ref: CollectionReference
        switch scope {
        case .public:
            ref = Firestore.firestore()
                .collection("public_chats")
                .document("global_chat")
                .collection("messages")
        case .privateChat(let chatID):
            try await moderationService.assertCanSendPrivateMessage(chatID: chatID)
            ref = Firestore.firestore()
                .collection("chats")
                .document(chatID)
                .collection("messages")
        }
        
        try await ref.document(message.id).setData(message.dictionary)
    }
    
    private func applyAttachmentEncryption(_ payload: EncryptedAttachmentPayload, to message: MessageModel) -> MessageModel {
        var encryptedMessage = message
        encryptedMessage.encryptedMessageKeys = payload.encryptedMessageKeys
        encryptedMessage.senderPublicKey = payload.senderPublicKey
        encryptedMessage.encryptionVersion = payload.encryptionVersion
        encryptedMessage.encryptionScheme = payload.encryptionScheme
        return encryptedMessage
    }
    
    private func savePrivateAttachmentMessage(_ message: MessageModel, chatID: String) async throws {
        try await moderationService.assertCanSendPrivateMessage(chatID: chatID)
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
    
    private func sendPrivateImageMessage(imageData: Data, chatID: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await moderationService.assertCanSendPrivateMessage(chatID: chatID)
        let messageID = UUID().uuidString
        let encryptedPayload = try await messageEncryptionService.encryptAttachmentData(imageData, chatID: chatID, messageID: messageID)
        let imageURL = try await chatMediaService.uploadImage(encryptedPayload.encryptedData, path: messageID, fileExtension: "bin")
        let message = MessageModel(
            id: messageID,
            senderUserID: uid,
            content: imageURL,
            timestamp: Timestamp(date: .now),
            type: .image
        )
        try await savePrivateAttachmentMessage(applyAttachmentEncryption(encryptedPayload, to: message), chatID: chatID)
    }
    
    private func sendPublicImageMessage(imageData: Data) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let messageID = UUID().uuidString
        let participants = try await chatPublicService.publicChatParticipantIDs()
        let encryptedPayload = try await messageEncryptionService.encryptAttachmentData(
            imageData,
            chatID: "global_chat",
            messageID: messageID,
            participantIDs: participants
        )
        let imageURL = try await chatMediaService.uploadImage(encryptedPayload.encryptedData, path: messageID, fileExtension: "bin")
        let message = MessageModel(
            id: messageID,
            senderUserID: uid,
            content: imageURL,
            timestamp: Timestamp(date: .now),
            type: .image
        )
        try await chatPublicService.sendPublicMessage(applyAttachmentEncryption(encryptedPayload, to: message))
    }
    
    func sendPrivateVoiceMessage(chatID: String, fileURL: URL, duration: Double) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await moderationService.assertCanSendPrivateMessage(chatID: chatID)
        let messageID = UUID().uuidString
        let audioData = try Data(contentsOf: fileURL)
        let encryptedPayload = try await messageEncryptionService.encryptAttachmentData(audioData, chatID: chatID, messageID: messageID)
        let audioURL = try await chatAudioService.uploadVoiceNoteData(encryptedPayload.encryptedData, path: messageID, fileExtension: "bin")
        let message = MessageModel(
            id: messageID,
            senderUserID: uid,
            content: audioURL,
            timestamp: Timestamp(date: .now),
            type: .audio,
            audioDuration: duration
        )
        try await savePrivateAttachmentMessage(applyAttachmentEncryption(encryptedPayload, to: message), chatID: chatID)
    }
    
    func sendPublicVoiceMessage(fileURL: URL, duration: Double) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let messageID = UUID().uuidString
        let audioData = try Data(contentsOf: fileURL)
        let participants = try await chatPublicService.publicChatParticipantIDs()
        let encryptedPayload = try await messageEncryptionService.encryptAttachmentData(
            audioData,
            chatID: "global_chat",
            messageID: messageID,
            participantIDs: participants
        )
        let audioURL = try await chatAudioService.uploadVoiceNoteData(encryptedPayload.encryptedData, path: messageID, fileExtension: "bin")
        let message = MessageModel(
            id: messageID,
            senderUserID: uid,
            content: audioURL,
            timestamp: Timestamp(date: .now),
            type: .audio,
            audioDuration: duration
        )
        try await chatPublicService.sendPublicMessage(applyAttachmentEncryption(encryptedPayload, to: message))
    }
    
    func decryptedImage(for message: MessageModel, chatID: String) async throws -> UIImage {
        guard let url = URL(string: message.content) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let imageData = try await messageEncryptionService.decryptAttachmentData(data, message: message, chatID: chatID)
        guard let image = UIImage(data: imageData) else {
            throw NSError(domain: "Imagen cifrada inválida", code: 0)
        }
        return image
    }
    
    // MARK: - Imagen desde URL (llamado por el chat público)
    /// Enlaza una URL de imagen ya subida al mensaje y lo envía al chat público.
    func sendImageMessage(with imageURL: String) async throws {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "No hay usuario autenticado", code: 401)
        }
        
        let message = MessageModel(id: UUID().uuidString,
                                   senderUserID: userID,
                                   content: imageURL,
                                   timestamp: Timestamp(),
                                   type: .image)
        
        try await chatPublicService.sendPublicMessage(message) // o privado
    }
    
    // MARK: - Guardar en carrete
    /// Descarga la imagen y la guarda en la fototeca del usuario.
    func saveToLibrary(imageURL: String) async {
        do {
            let localURL = try await chatMediaService.downloadAndStoreImageLocally(from: imageURL)
            let data = try Data(contentsOf: localURL)
            
            guard let image = UIImage(data: data) else {
                throw NSError(domain: "Imagen inválida", code: 0)
            }
            
            try await chatMediaService.saveImageToPhotoLibrary(image)
            AppLogger.debug("Imagen guardada en el carrete.")
            
        } catch {
            showError = true
            errorTitle = "Error al guardar"
            errorMessage = "No se pudo guardar la imagen en el carrete."
            AppLogger.error("Error al guardar imagen.")
        }
    }
    
    // MARK: - Borrar imagen
    /// Elimina la imagen tanto localmente como en Storage.
    func deleteImage(message: MessageModel) async {
        do {
            let localURL = try await chatMediaService.downloadAndStoreImageLocally(from: message.content)
            try await chatMediaService.deleteImage(localURL: localURL, storageURL: message.content)
            AppLogger.debug("Imagen eliminada.")
            
        } catch {
            showError = true
            errorTitle = "Error al eliminar"
            errorMessage = "No se pudo eliminar la imagen del dispositivo o de Firebase."
            AppLogger.error("Error al eliminar imagen.")
        }
    }
    
    // MARK: - Nota de voz
    /// Crea y envía un mensaje `.audio` con su duración.
    func sendVoiceMessage(scope: ChatScope, url: String, duration: Double) async throws{
        do{
            guard let currentUserID = Auth.auth().currentUser?.uid else {
                AppLogger.warning("Usuario no encontrado.")
                return
            }
            let ref = Firestore.firestore()
            
            let message = MessageModel(
                id: UUID().uuidString,
                senderUserID: currentUserID,
                content: url,
                timestamp: Timestamp(date: .now),
                type: .audio,
                audioDuration: duration
            )
            
            switch scope{
                
            case .public:
                try await saveMessage(
                    to:ref
                    .collection("public_chats")
                    .document("global_chat")
                    .collection("messages")
                    , message: message)
                
            case .privateChat(let chatID):
                try await moderationService.assertCanSendPrivateMessage(chatID: chatID)
                
                try await saveMessage(
                    to: Firestore.firestore()
                    .collection("chats")
                    .document(chatID)
                    .collection("messages"),
                    message: message)
            }

        }catch{
            showError = true
            errorTitle = "Error al enviar nota de voz"
            errorMessage = "No se pudo guardar el mensaje con la URL del audio."
        }
    }
    
    // MARK: - Helpers
    /// Persistencia genérica de mensajes.
    private func saveMessage(to ref: CollectionReference, message: MessageModel) async throws {
        try await ref.document(message.id).setData(message.dictionary)
    }
    
    /// Comprime, sube y envía una foto tomada con la cámara.
    func sendCameraImage(_ image: UIImage, scope: ChatScope) async throws {
        guard let data = await chatMediaService.compressImage(image) else { return }
        switch scope {
        case .public:
            try await sendPublicImageMessage(imageData: data)
        case .privateChat(let chatID):
            try await sendPrivateImageMessage(imageData: data, chatID: chatID)
        }
    }
    
}
