//
//  ChatAudioService .swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 18/4/25.
//

import Foundation
import AVFoundation
import FirebaseStorage

/// Servicio exclusivo para gestionar grabación, almacenamiento, descarga y reproducción de notas de voz.
actor ChatAudioService {
    private var audioRecorder: AVAudioRecorder?
    
    // MARK: - Grabación
    
    /// Inicia la grabación de audio y devuelve la URL local donde se está guardando el archivo.
    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try session.setActive(true)
        
        // Validar permisos de micrófono
        var permissionGranted = false
        let semaphore = DispatchSemaphore(value: 0)
        AVAudioApplication.requestRecordPermission { granted in
            permissionGranted = granted
            semaphore.signal()
        }
        semaphore.wait()
        
        guard permissionGranted else {
            throw NSError(domain: "ChatAudioService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Permiso de micrófono denegado."
            ])
        }
        
        let filename = UUID().uuidString + ".m4a"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        
        guard recorder.record() else {
            throw NSError(domain: "ChatAudioService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "No se pudo iniciar la grabación."
            ])
        }
        
        audioRecorder = recorder
        return fileURL
    }
    
    /// Detiene la grabación actual y devuelve la URL del archivo grabado.
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder else {
            print("Error: No hay grabadora activa.")
            return nil
        }
        
        recorder.stop()
        let url = recorder.url
        audioRecorder = nil // Limpieza
        return url
    }
    
    // MARK: - Subida y eliminación en Firebase
    
    /// Sube una nota de voz a Firebase Storage y devuelve su URL pública.
    func uploadVoiceNote(_ fileURL: URL, path: String = UUID().uuidString) async throws -> String {
        let audioData = try Data(contentsOf: fileURL)
        let storageRef = Storage.storage().reference().child("voice_notes/\(path).m4a")
        
        return try await Task.detached(priority: .userInitiated) {
            _ = try await storageRef.putDataAsync(audioData)
            let url = try await storageRef.downloadURL()
            return url.absoluteString
        }.value
    }
    
    /// Elimina una nota de voz de Firebase Storage dada su URL.
    func deleteVoiceNote(from storageURL: String) async throws {
        do {
            let ref = Storage.storage().reference(forURL: storageURL)
            try await ref.delete()
            print("Nota de voz eliminada del servidor.")
        } catch {
            print("Error: No se pudo eliminar la nota de voz. \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Descarga y almacenamiento local (caché)
    
    /// Descarga una nota de voz desde una URL remota y la guarda en caché local.
    /// Devuelve la ruta local del archivo guardado.
    func downloadAndCacheVoiceNote(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let filename = UUID().uuidString + ".m4a"
        let localURL = cachesDir.appendingPathComponent(filename)
        
        try data.write(to: localURL)
        return localURL
    }
    
    /// Verifica si existe una copia local en caché de un archivo dado un identificador.
    func cachedFileExists(for filename: String) -> URL? {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cachesDir.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    /// Devuelve la potencia de audio actual normalizada del grabador.
    /// Asegúrate de que `isMeteringEnabled = true` esté configurado cuando se inicia la grabación.
    func getAveragePower() -> Float {
        guard let recorder = audioRecorder else { return 0 }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let level = pow(10, power / 20)
        return max(0.05, Float(level))
    }

}
