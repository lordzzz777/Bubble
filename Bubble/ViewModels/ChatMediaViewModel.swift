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
    private let chatPublicService = PublicChatService()
   
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
            
            // 3. Subir imagen a Firebase y obtener URL
            let imageURL = try await chatMediaService.uploadImage(imageData)
            
            // 4. Crear y enviar mensaje
            try await sendImageMessage(with: imageURL)
            
            try await sendImageMessage(with: imageURL, scope: scope)
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
            ref = Firestore.firestore()
                .collection("chats")
                .document(chatID)
                .collection("messages")
        }
        
        try await ref.document(message.id).setData(message.dictionary)
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
            print("Imagen guardada en el carrete con éxito.")
            
        } catch {
            showError = true
            errorTitle = "Error al guardar"
            errorMessage = "No se pudo guardar la imagen en el carrete."
            print("Error al guardar imagen: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Borrar imagen
    /// Elimina la imagen tanto localmente como en Storage.
    func deleteImage(message: MessageModel) async {
        do {
            let localURL = try await chatMediaService.downloadAndStoreImageLocally(from: message.content)
            try await chatMediaService.deleteImage(localURL: localURL, storageURL: message.content)
            print("Imagen eliminada con éxito.")
            
        } catch {
            showError = true
            errorTitle = "Error al eliminar"
            errorMessage = "No se pudo eliminar la imagen del dispositivo o de Firebase."
            print("Error al eliminar imagen: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Nota de voz
    /// Crea y envía un mensaje `.audio` con su duración.
    func sendVoiceMessage(scope: ChatScope, url: String, duration: Double) async throws{
        do{
            guard let currentUserID = Auth.auth().currentUser?.uid else {
                print("Usuario no encontrado")
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
        let url = try await chatMediaService.uploadImage(data)
        try await sendImageMessage(with: url, scope: scope)
    }
    
}

