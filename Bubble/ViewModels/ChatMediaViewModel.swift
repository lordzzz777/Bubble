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

@Observable @MainActor
class ChatMediaViewModel{
    private let chatMediaService = ChatMediaService()
    private let chatPublicService = PublicChatService()
    var audioPlayer: AVAudioPlayer?
    
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
    
    
    // MARK: - ViewModel Grabación de notas de voz ...
    
    /// Inicia grabación de voz y retorna la URL temporal del archivo.
    func startVoiceRecording() async throws -> URL? {
        do{
            let url = try await chatMediaService.startRecording()
            return url
        }catch{
            showError = true
            errorTitle = "Error al grabar"
            errorMessage = "No se pudo iniciar la grabación: \(error.localizedDescription)"
            print("Error al iniciar grabación: \(error)")
            throw error
        }
    }
    
    /// Finaliza la grabación y retorna la URL local del archivo.
    func deleteGrabation() async -> URL? {
        
        let url =  await chatMediaService.stopRecording()
        if url == nil {
            showError = true
            errorTitle = "Error al detener"
            errorMessage = "No se pudo detener la grabacion"
        }
        
        return url
        
    }
    
    /// Sube el audio y lo envía como mensaje al chat.
    func uploadNoteVoice(url: URL) async throws -> String? {
        do{
            let remoteURL = try await chatMediaService.uploadVoiceNote(url)
            return remoteURL
        }catch{
            showError = true
            errorTitle = "Error al subir"
            errorMessage = "No se pudo subir la nota de voz: \(error.localizedDescription)"
            print("Error al subir nota de voz: \(error)")
            throw error
        }
    }
    
    /// Crea y envía un mensaje con URL de nota de voz.
    func sendNoteVoiceConURL(_ voiceNoteURL: String, audioDuration: Double?) async throws {
        do{
            guard let userID = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "No hay usuario autenticado", code: 401)
            }
            
            let message = MessageModel(
                id: UUID().uuidString,
                senderUserID: userID,
                content: voiceNoteURL,
                timestamp: Timestamp(),
                type: .audio,
                audioDuration: audioDuration
            )
            
            try await chatPublicService.sendPublicMessage(message)
        }catch{
            showError = true
            errorTitle = "Error al enviar nota de voz"
            errorMessage = error.localizedDescription
            print("Error al enviar nota de voz: \(error)")
        }
    }
    
    /// Reproduce una nota de voz desde una URL remota.
    func playVoiceMessage(url: String) async {
        do{
            let localURL = try await chatMediaService.downloadVoiceNote(from: url)
            let data = try Data(contentsOf: localURL)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        }catch{
            showError = true
            errorTitle = "Error de reproducción"
            errorMessage = "No se pudo reproducir la nota de voz: \(error.localizedDescription)"
        }
    }
    
    /// Pausar la reproducción actual
    func pauseVoceNote(){
        audioPlayer?.pause()
    }
    
    /// Reanudar reproducción
    func resumeVoiceNote(){
        audioPlayer?.play()
    }
    
    /// Detiene la reproducción actual.
    func stopVoicePlayBack(){
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    /// Retorna el tiempo de reproducción actual en segundos.
    func currentPlaybackTime() -> TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }
    
    /// Formatea el tiempo actual de reproducción de audio a un string legible en formato "mm:ss".
    ///
    /// Esta función toma el tiempo actual de reproducción (en segundos) obtenido desde el `audioPlayer`,
    /// lo convierte a minutos y segundos, y devuelve un string con formato "00:00".
    /// Si no hay reproducción activa, el tiempo será `0`.
    ///
    /// - Returns: Un string representando el tiempo actual de reproducción en formato "minutos:segundos".
    func formatPlaybackTime() -> String {
        let time = Int(currentPlaybackTime())
        let minute = time / 60
        let seconds = time % 60
        
        return String(format: "%02d:%02d", minute, seconds)
    }
    
    
}

