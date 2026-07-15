//
//  ForwardViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 11/6/25.
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@Observable @MainActor
final class ForwardViewModel{
    
    // Inyección del servicio
    private let service = ForwardService()
    
    // Selección
    var selecting = false
    var selected  = [MessageModel]()
    var sourceChatID: String?
    
    var targets: [String : String] = [:]
    var chosenIDs = Set<String>()
    
    // Progreso y errores
    var progress:  Double = 0
    var failures:  [String] = []
    
    // Mesajes de error
    var showError: Bool = false
    var errorTitle: String = ""
    var errorMessage: String = ""
    
    //MARK: - Acción principal
    func forward() async {
        guard let myUID = Auth.auth().currentUser?.uid, !selected.isEmpty, !chosenIDs.isEmpty else {
            AppLogger.debug("No hay contenido válido para reenviar.")
            return
        }
        
        // 1 ▸ Asegurar (o crear) chats
        var chatIDs = [String]()
        var failures = [String]()
        
        for uid in chosenIDs {
            do {
                let id = try await service.ensurePrivateChat(with: uid,
                                                             currentUID: myUID)
                chatIDs.append(id)     
            } catch {
                AppLogger.error("No se pudo preparar el chat de reenvío.")
                failures.append(uid)
                continue
            }
        }
        
        // 2 ▸ Copiar mensajes
        do    { try await service.forward(selected, to: chatIDs, sourceChatID: sourceChatID) }
        catch {
            showError("Fallo al reenviar", error.localizedDescription)
        }
        
        // 3 ▸ Reset
        selected.removeAll(); chosenIDs.removeAll(); sourceChatID = nil; selecting = false
        
    }
    
    /// Muestra una alerta genérica en la UI.
    ///  - Parámetros:
    ///    - title: Título de la alerta.
    ///    - msg:   Mensaje descriptivo.
    ///  Internamente rellena las propiedades ligadas a la vista
    ///  (`errorTitle`, `errorMessage`) y activa `showError` para que
    ///  SwiftUI presente el `Alert`.
    private func showError( _ title: String, _ msg: String) {
        errorTitle = title; errorMessage = msg; showError = true
    }
    
    /// Alterna la selección de un mensaje en el array `selected`.
    ///  - Si el mensaje ya estaba seleccionado → lo elimina.
    ///  - Si no estaba → lo añade al final.
    ///  Se usa para construir la lista de mensajes que el usuario
    ///  quiere reenviar.
    func toggle(_ m: MessageModel){
        if let i = selected.firstIndex(of: m){
            selected.remove(at: i)
        }else {
            selected.append(m)
        }
    }
}
