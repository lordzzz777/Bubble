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

@Observable @MainActor
class ChatMediaViewModel{
    private let chatMediaService = ChatMediaService()
    private let chatPublicService = PublicChatService()
    
    var message: [MessageModel] = []
    var showError: Bool = false
    var errorTitle: String = ""
    var errorMessage: String = ""
    
    /// Envía un mensaje con imagen seleccionada desde el picker.
    func sendImageFromPicker(_ pickerItem: PhotosPickerItem?) async {
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
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    
    /// Crea y envía un mensaje con URL de imagen.
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
    
    /// Guarda una imagen en el carrete del usuario a partir de una URL
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

    
    /// Elimina imagen local y de Firebase Storage
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

}
