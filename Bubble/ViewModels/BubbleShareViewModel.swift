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
    
    // Estado por Buebuja (Cada instacia se vive detras de la vista)
    var localURL: URL? = nil
    var isWorking = false
    var isShowError: Bool = false
    var errorTitleMessage: String? = nil
    var errorMessage: String? = nil
    
    
    /// Pre-descarga si es necesario. Se llama desde `.task` en la burbuja.
    func prepare(for message: MessageModel) async {
        guard message.type == .file || message.type == .audio else {return}
        
        guard let url = URL(string: message.content) else {return}
        
        isWorking = true
        
        do{
            localURL = try await cache.localURL(for: url)
        }catch{
             isShowError = true
            errorTitleMessage = "No se puede descargar"
            errorMessage = "No se pudo descargar para compartir."
        }
        
        isWorking = false
    }
    
    /// Devuelve el `Transferable` listo para ShareLink o nil si aún no está.
    func shareItem(for message: MessageModel) -> (any Transferable)? {
        switch message.type {
        case .text:
            return message.content
        case .image:
            return URL(string: message.content)
        case .file, .audio:
            return localURL
        default:
            return nil
        }
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
