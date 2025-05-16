//
//  ChatMediaService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 7/4/25.
//

import AVFoundation
import FirebaseStorage
import PhotosUI
import SwiftUI
import Photos


enum MediaPickerError: Error {
    case noSelection
    case invalidData
}

// MARK: - Service Imajenes en chats
actor ChatMediaService{
    
    private var audioRecorder: AVAudioRecorder?
    
    /// Selecciona una imagen desde la galería usando `PhotosPickerItem`.
    func pikerImage(from selection: PhotosPickerItem?) async throws -> UIImage {
        guard let item = selection else {
            throw MediaPickerError.noSelection
        }
        
        let data = try await item.loadTransferable(type: Data.self)
        
        guard let imageData = data, let image = UIImage(data: imageData) else {
            throw MediaPickerError.invalidData
        }
        
        return image
    }
        
    /// Toma una foto usando la cámara (requiere integración con ImagePicker representable).
    func takePhotoWithCamera() {
        // ....
    }
    
    /// Comprime la imagen al tamaño deseado.
    func compressImage(_ image: UIImage) -> Data?{
        return image.pngData()
    }
    
    /// Sube una imagen comprimida a Firebase Storage y retorna la URL.
    func uploadImage(_ data: Data, path: String = UUID().uuidString) async throws -> String {
        let storageRef = Storage.storage().reference().child("chat_images/\(path).png")
        
        return try await Task.detached(priority: .userInitiated) {
            _ = try await storageRef.putDataAsync(data)
            let url = try await storageRef.downloadURL()
            return url.absoluteString
        }.value
    }
    
    /// Descarga una imagen desde la URL y la guarda en el almacenamiento local.
    /// Retorna la ruta local del archivo guardado.
    func downloadAndStoreImageLocally(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Ruta del deldirectorio local
        let fileMannager = FileManager.default
        let cachesDir = fileMannager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let filename = UUID().uuidString + ".png"
        let localURL = cachesDir.appendingPathComponent(filename)
        
        // Guarda la imagen en disco
        try data.write(to: localURL)
        
        return localURL
    }
    
    /// Elimina una imagen del almacenamiento local **y** de Firebase Storage.
    /// - Parameter localURL: Ruta del archivo local.
    /// - Parameter storageURL: URL completa de Firebase Storage.
    func deleteImage(localURL: URL, storageURL: String) async throws {
        // Elimina localmente
        let fileMannager = FileManager.default
        if fileMannager.fileExists(atPath: localURL.path){
            do{
                try fileMannager.removeItem(at: localURL)
                print("Imagen eliminada localmente.")
            }catch{
                print("Error no se ha podido eliminar: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Eliminar de Firebase Storage
        let ref = Storage.storage().reference(forURL: storageURL)
        
        do{
            try await ref.delete()
            print("Imagen eliminada de Firebase Storage.")
        }catch{
            print("Error al eliminar de Firebase Storage: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Guarda una imagen en la galería del usuario.
    func saveImageToPhotoLibrary(_ image: UIImage) async throws{
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    // MARK: - Service Grabación de notas de voz ...
    
    /// Inicia la grabación de una nota de voz y guarda el archivo localmente.
    func startRecording() throws -> URL {
        let filename = UUID().uuidString + ".m4a"
        let dir = FileManager.default.temporaryDirectory
        let fileURL = dir.appendingPathComponent(filename)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.record()
        
        return fileURL
    }
    
    /// Finaliza la grabación y devuelve la URL local del archivo de audio.
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder else {
            print("Error: No hay grabadora activa.")
            return nil
        }
        
        recorder.stop()
        let url = recorder.url
        audioRecorder = nil // Limpieza de la instancia
        return url
    }
    
}
