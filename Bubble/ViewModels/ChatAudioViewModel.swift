//
//  ChatAudioViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 18/4/25.
//

@preconcurrency import AVFoundation
import FirebaseAuth
import FirebaseFirestore
import Foundation
import SwiftUI
import Observation

@Observable @MainActor
final class ChatAudioViewModel:  NSObject, @preconcurrency AVAudioPlayerDelegate {
    private let audioService: ChatAudioService = ChatAudioService()
    private let messageEncryptionService = MessageEncryptionService()
    
    // MARK: - Estados públicos observables
    var isRecording = false
    var isUploading = false
    var isShowError: Bool = false
    var isPlaying = false
    
    var player: AVAudioPlayer?
    var localAudioURL: URL?
    var recordingStartTime: Date?
    var waveformSamples: [CGFloat] = []
    var liveRecordingSamples: [CGFloat] = []
    
    var errorMessage: String?
    var errorTitleMessage: String?
    var uploadedAudioURL: String?
    
    var audioDuration: Double? = nil
    var currentPlaybackTime: Double = 0
    var recordingElapsed: TimeInterval = 0
    
    var recordingElapsedTime: String {
        let total = Int(recordingElapsed)
        let min = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", min, sec)
    }

    
    
    // MARK: - Grabación
    
    /// Inicia la grabación de audio y guarda la URL del archivo local.
    func startRecording() async throws {
        
        do {
            let url = try await audioService.startRecording()
            localAudioURL = url
            recordingStartTime = Date()
            isRecording = true
            liveRecordingSamples.removeAll()
            
        } catch {
            isShowError = true
            errorTitleMessage = "Error: Iniciar grabación"
            errorMessage = "No se pudo iniciar la grabación"
            throw error
        }
    }
    
    /// Detiene la grabación, valida el archivo y calcula la duración.
    func stopRecording() async{
        guard let url = await audioService.stopRecording() else {
            errorTitleMessage = "Error: Detener grabación"
            errorMessage = "No se pudo detener la grabación."
            isShowError = true
            return
        }
        
        do{
            let fileAtributes = try FileManager.default.attributesOfItem(atPath: url.path())
            let fileSize = fileAtributes[.size] as? UInt64 ?? 0
            
            guard fileSize > 0 else {
                AppLogger.warning("Archivo vacío, cancelando grabación.")
                errorTitleMessage = "Error: Archivo inválido"
                errorMessage = "La grabación está vacía o fue demasiado corta."
                isShowError = true
                try? FileManager.default.removeItem(at: url) // elimina archivo inválido
                return
            }

        }catch{
            errorTitleMessage = "Error: Validación"
            errorMessage = "No se pudo validar la grabación: \(error.localizedDescription)"
            isShowError = true
            return
        }
        
        localAudioURL = url
        
        // valida duración minima antes de continuar
        if let start = recordingStartTime{
            let duration = Date().timeIntervalSince(start)
            if duration < 0.3 {
                errorTitleMessage = "Error: tiempo de grabacion"
                errorMessage = "grabacion demasiado corta, sera descartada ..."
                AppLogger.debug("Grabación demasiado corta, descartada.")
                
                audioDuration = 0
                
                try? FileManager.default.removeItem(at: url)
                recordingStartTime = nil
                return
            }
        }
        
        isRecording = false
        audioDuration = calcularDuracionAudio(url: url)
        recordingStartTime = nil
    }
    
    // MARK: - Subida
    
    /// Sube la nota de voz a Firebase Storage y guarda la URL resultante.
    func uploadVoiceNote() async throws {
        guard let localURL = localAudioURL else {
            errorTitleMessage = "Error: Subida de audio"
            errorMessage = "No hay audio grabado para subir."
            isShowError = true
            return
        }
        
        isUploading = true
        
        do {
            let urlString = try await audioService.uploadVoiceNote(localURL)
            uploadedAudioURL = urlString
        } catch {
            errorTitleMessage = "Error: Subida"
            errorMessage = "No se ha podido subir el audio: \(error.localizedDescription)"
            isShowError = true
            throw error
        }
        
        isUploading = false
    }
    
    // MARK: - Utilidades
    
    /// Elimina una nota de voz del servidor de Firebase Storage.
    /// - Parameter storageURL: URL completa del archivo en Firebase Storage.
    func deleteVoiceNote(from storageURL: String) async throws {
        do{
            try await audioService.deleteVoiceNote(from: storageURL)
            AppLogger.debug("Nota de voz eliminada correctamente.")
            
            uploadedAudioURL = nil
            localAudioURL = nil
            audioDuration = nil
            
        }catch{
            isShowError = true
            errorTitleMessage = "Error: al eliminar nota de voz"
            errorMessage = "No se pudo eliminar la nota de voz del servidor."
            throw error
        }
        
    }
    
    /// Calcula la duración del archivo de audio desde una URL local.
    private func calcularDuracionAudio(url: URL) -> Double {
        // 1. Validar existencia del archivo
        guard FileManager.default.fileExists(atPath: url.path) else {
            AppLogger.warning("El archivo de audio no existe.")
            return 0
        }
        
        // 2. Validar tamaño del archivo
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            guard fileSize > 0 else {
                AppLogger.warning("Archivo de audio vacío.")
                return 0
            }
        } catch {
            AppLogger.error("Error leyendo atributos del archivo de audio.")
            return 0
        }
        
        // 3. Intentar abrir como AVAudioFile
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = file.length
            let duration = Double(frameCount) / format.sampleRate
            return duration
        } catch {
            AppLogger.error("Error al calcular duración del audio.")
            return 0
        }
    }

    /// Resetea todos los estados relacionados al audio.
    func reset() {
        cleanupLocalAudioFile()
        isRecording = false
        isUploading = false
        isPlaying = false
        errorMessage = nil
        errorTitleMessage = nil
        localAudioURL = nil
        uploadedAudioURL = nil
        audioDuration = nil
        currentPlaybackTime = 0
        player = nil
        recordingStartTime = nil
        liveRecordingSamples.removeAll()
    }

    func cleanupLocalAudioFile() {
        stopPlayback()
        LocalFilePrivacyService.removeProtectedTemporaryFile(at: localAudioURL)
        localAudioURL = nil
    }
    
    // MARK: - Descarga & Reproducción
    
    /// Descarga y cachea un archivo de audio desde una URL remota.
    func downloadAndCacheAudio(from urlString: String) async throws -> URL? {
        do {
            return try await audioService.downloadAndCacheVoiceNote(from: urlString)
        } catch {
            errorTitleMessage = "Error: descarga de audio"
            errorMessage = error.localizedDescription
            isShowError = true
            return nil
        }
    }
    
    func downloadAndCacheEncryptedAudio(message: MessageModel, chatID: String) async throws -> URL? {
        do {
            guard let url = URL(string: message.content) else { throw URLError(.badURL) }
            let (encryptedData, _) = try await URLSession.shared.data(from: url)
            let audioData = try await messageEncryptionService.decryptAttachmentData(encryptedData, message: message, chatID: chatID)
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let localURL = cachesDir.appendingPathComponent("\(message.id).m4a")
            try audioData.write(to: localURL)
            try LocalFilePrivacyService.protectCacheFile(at: localURL)
            return localURL
        } catch {
            errorTitleMessage = "Error: descarga de audio"
            errorMessage = error.localizedDescription
            isShowError = true
            return nil
        }
    }
    
    /// Reproduce un archivo de audio desde una URL local.
    func playAudio(from url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            // Extrae duración desde el player si no está establecida
            if audioDuration == nil || audioDuration == 0 {
                audioDuration = player?.duration
                AppLogger.debug("Duración de audio cargada desde el reproductor.")
            }
            
            Task{
                await extractWaveformSamples(from: url)
            }
            player?.play()
            isPlaying = true
            AppLogger.debug("Iniciando reproducción de audio.")
            startProgressUpdater()
            
        } catch {
            isShowError = true
            errorTitleMessage = "Error: reproducción"
            errorMessage = "No se pudo reproducir el audio."
        }
    }
    
    /// Actualiza continuamente el tiempo de reproducción mientras el audio está en curso.
    func startProgressUpdater() {
        Task {
            AppLogger.debug("Iniciando actualización de progreso de audio.")
            while isPlaying {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 segundos
                await MainActor.run {
                    if let player = player {
                        currentPlaybackTime = player.currentTime
                       // AppLogger.debug("Tiempo de reproducción actualizado.")
                    }
                }
            }
        }
    }

    // Formatear segundos como "mm:ss"
    func formattedTime(from seconds: Double) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }

    /// Pausa la reproducción de audio.
    func pausePlayback() {
        player?.pause()
        isPlaying = false
    }
    
    /// Detiene completamente la reproducción.
    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
    }
    
    /// Delegate de AVAudioPlayer para detectar el final de la reproducción.
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentPlaybackTime = 0
    }
    
    /// Extrae una forma de onda simplificada desde un archivo de audio.
    func extractWaveformSamples(from url: URL, sampleCount: Int = 30) async {
        let asset = AVURLAsset(url: url)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { return }
            let readerSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32
            ]
            
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: readerSettings)
            reader.add(output)
            reader.startReading()
            
            var samples: [Float] = []
            
            while let buffer = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(buffer) {
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)
                samples += data
            }
            
            let chunkSize = max(samples.count / sampleCount, 1)
            let waveform: [CGFloat] = (0..<sampleCount).map { i in
                let start = i * chunkSize
                let end = min(start + chunkSize, samples.count)
                let chunk = samples[start..<end]
                let maxAmp = chunk.map { abs($0) }.max() ?? 0
                return CGFloat(maxAmp)
            }
            
            await MainActor.run {
                self.waveformSamples = waveform
            }
            
        } catch {
            AppLogger.error("Error extrayendo forma de onda.")
        }
    }
    
    /// Alterna entre reproducción y pausa, y actualiza el progreso visual en la UI.
    func togglePlayback(from urlString: String, message: MessageModel? = nil, chatID: String? = nil, progressBinding: Binding<CGFloat>) {
        Task {
            if isPlaying {
                pausePlayback()
                progressBinding.wrappedValue = 0
                return
            }
            
            // Descargar si es necesario
            if localAudioURL == nil {
                if let message, let chatID, message.encryptionVersion != nil {
                    localAudioURL = try? await downloadAndCacheEncryptedAudio(message: message, chatID: chatID)
                } else {
                    localAudioURL = try? await downloadAndCacheAudio(from: urlString)
                }
            }
            
            guard let url = localAudioURL else {
                AppLogger.warning("URL local no disponible para reproducción.")
                return
            }
            
            // Reproducir
            playAudio(from: url)
            
            // Esperar a que `audioDuration` se establezca
            try? await Task.sleep(nanoseconds: 400_000_000)
            while isPlaying {
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                let duration = audioDuration ?? 0
                guard duration > 0 else {
                    continue
                }
                
                let progress = currentPlaybackTime / duration
                await MainActor.run {
                    progressBinding.wrappedValue = CGFloat(progress)
                }
            }
        }
    }
    
    /// Agrega una nueva muestra a la forma de onda en tiempo real.
    /// - Parameter level: valor normalizado (0.0 a 1.0) representando la potencia del micrófono.
    func appendLiveSample (_ value: CGFloat, maxSamples: Int = 30){
        Task{ @MainActor in
            if liveRecordingSamples.count >= maxSamples{
                liveRecordingSamples.removeFirst()
            }
            liveRecordingSamples.append(value)
            
        }
    }
    
    /// Inicia un bucle que actualiza la forma de onda durante la grabación en tiempo real.
    /// Esta función consulta periódicamente el nivel de audio del micrófono desde `ChatAudioService`
    /// y lo envía a la vista principal para mostrarlo como una animación en vivo.
    func startRecordingWaveformUpdates() async {
        
        while isRecording {
            do {
                // Espera 200 milisegundos entre cada muestra
                try await Task.sleep(nanoseconds: 200_000_000)
                
                // Obtener el nivel de audio actual desde el actor (de forma segura)
                let level = await audioService.getAveragePower()
                
                // Actualizar visualmente desde el hilo principal
                await MainActor.run {
                    self.appendLiveSample(CGFloat(level))
                    
                    // Actualizar tiempo de grabación
                    if let start = self.recordingStartTime {
                        self.recordingElapsed = Date().timeIntervalSince(start)
                    }
                }
            } catch {
                AppLogger.error("Error al actualizar la onda de grabación.")
            }
        }
    }

}

