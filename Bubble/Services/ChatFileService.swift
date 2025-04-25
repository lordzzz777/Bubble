//
//  ChatFileService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 24/4/25.
//

import Foundation
import FirebaseStorage
import UniformTypeIdentifiers

actor ChatFileService {
    
    /// Sube un archivo al servidor (Firebase Storage) y retorna su URL.
    /// - Parameters:
    ///   - fileURL: URL local del archivo.
    ///   - path: Ruta opcional para personalizar la carpeta de subida.
    func upploadFile(_ fileURL: URL, path: String = UUID().uuidString) async throws -> String {
        let fileeData = try Data(contentsOf: fileURL)
        let fileExtension = fileURL.pathExtension
        let storageRef = Storage.storage().reference().child("shared_files/\(path).\(fileExtension)")
        
        return try await Task.detached(priority: .userInitiated){
            _ = try await storageRef.putDataAsync(fileeData)
            let url = try await storageRef.downloadURL()
            return url.absoluteString
        }.value
    }
    
    /// Descarga un archivo desde Firebase Storage a la carpeta temporal y retorna su URL local.
    func downloadFile(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _ ) = try await URLSession.shared.data(from: url)
        let filename = UUID().uuidString
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: tempURL)
        return tempURL
    }
    
    /// Extrae el tipo de archivo desde la URL usando UTType.
    func extractFileType(from url: URL) -> String {
        guard let utType = UTType(filenameExtension: url.pathExtension) else {
            return "archivo"
        }
        
        return utType.localizedDescription ?? "archivo"
    }
    
    /// Guarda un archivo descargado temporalmente en la carpeta de documentos del usuario.
    /// - Parameters:
    ///   - tempURL: URL temporal donde se descargó el archivo.
    ///   - originalFilename: El nombre con el que se desea guardar.
    /// - Returns: URL del archivo guardado permanentemente.
    func saveDownloadedFileLocally(tempURL: URL, originalFilename: String) throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent(originalFilename)
        
        if fileManager.fileExists(atPath: destinationURL.path){
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: tempURL, to: destinationURL)
        return destinationURL
    }
    
    /// Valida que el archivo no exceda un tamaño máximo permitido (en MB).
    ///
    /// - Parameters:
    ///   - fileURL: URL local del archivo que se va a validar.
    ///   - maxSizeInMB: Tamaño máximo permitido en megabytes (por defecto: 25 MB).
    /// - Throws: Un error si el archivo excede el límite especificado
    func validateFileSize(_ fileURL: URL, maxSizeInMB: Double = 25) throws {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        
        if let filesize = fileAttributes[.size] as? UInt64 {
            let sizeInMB = Double(filesize) / (1024 * 1024)
            
            if sizeInMB > maxSizeInMB {
                throw NSError(domain: "ChatFileService", code: 1, userInfo: [ NSLocalizedDescriptionKey: "El archivo excede el límite de \(maxSizeInMB) MB."])
            }
        }
    }
    
    /// Elimina un archivo del almacenamiento de Firebase dado su URL.
    ///
    /// - Parameter storageURL: URL completo del archivo en Firebase Storage.
    /// - Throws: Un error si no se puede eliminar el archivo.
    func deleteFileFromStorage(_ storageURL: String) async throws {
        do{
            let ref = Storage.storage().reference(forURL: storageURL)
            try await ref.delete()
            print("Archivo eliminado correctamente de Firebase Storage.")
            
        }catch{
            print("Info Service: Error al eliminar archivo de Firebase Storage: \(error.localizedDescription)")
            throw error
        }
    }
}
