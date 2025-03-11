//
//  PrivateChatViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import Foundation
import FirebaseAuth

@Observable @MainActor
class PrivateChatViewModel {
    
    private let privateChatService: PrivateChatService = PrivateChatService()
    
    var messages: [MessageModel] = []
    var showError: Bool = false
    var errorTitle: String = ""
    var errorMessage: String = ""
    
    /// Obtiene los mensajes de un chat privado y los ordena por timestamp.
    ///
    /// - Parameter chatID: El identificador del chat del cual se desean obtener los mensajes.
    func fetchMessages(chatID: String) {
         privateChatService.fetchMessagesFromChat(chatID: chatID) { [weak self] result in
                switch result {
                case .success(let messages):
                    self?.messages = messages
                    self?.messages.sort(by: { $0.timestamp.seconds < $1.timestamp.seconds })
                case .failure(let error):
                    self?.errorTitle = "Error al obtener mensajes"
                    self?.errorMessage = "Hubo un error al intentar obtener los mensajes. Por favor, inténtalo más tarde."
                    print(error.localizedDescription)
                    self?.showError = true
                }
            }
    }
    
    /// Envía un mensaje en un chat privado.
    ///
    /// - Parameters:
    ///   - chatID: El identificador del chat en el que se enviará el mensaje.
    ///   - messageText: El contenido del mensaje que se desea enviar.
    func sendMessage(chatID: String, messageText: String) async {
        do {
            try await privateChatService.sendMessage(chatID: chatID, messageText: messageText)
        } catch {
            errorTitle = "No se pudo enviar mensaje"
            errorMessage = "Hubo un error al intentar enviar el mensaje. Por favor, inténtalo más tarde."
            showError = true
            print(error.localizedDescription)
        }
    }
    
    /// Verifica si un mensaje fue enviado por el usuario autenticado.
    ///
    /// - Parameter message: El mensaje que se desea comprobar.
    /// - Returns: `true` si el mensaje fue enviado por el usuario autenticado, `false` en caso contrario.
    func checkIfMessageWasSentByCurrentUser(_ message: MessageModel) -> Bool {
        return message.senderUserID == Auth.auth().currentUser?.uid
    }
}
