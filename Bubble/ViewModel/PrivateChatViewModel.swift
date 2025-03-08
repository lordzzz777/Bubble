//
//  PrivateChatViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import Foundation
import FirebaseAuth
import FirebaseCore

@Observable @MainActor
class PrivateChatViewModel {
    private let privateChatService: PrivateChatService = PrivateChatService()
    var messages: [MessageModel] = []
    var showError: Bool = false
    var errorTitle: String = ""
    var errorMessage: String = ""
    
    var lastMessage: MessageModel = MessageModel(id: "", senderUserID: "", content: "", timestamp: .init(), type: MessageType.text)
    
    func fetchMessages(chatID: String) {
         privateChatService.fetchMessagesFromChat(chatID: chatID) { [weak self] result in
                switch result {
                case .success(let messages):
                    self?.messages = messages
                    self?.messages.sort(by: { $0.timestamp.seconds < $1.timestamp.seconds })
                    if let lastMessage = self?.messages.last {
                        self?.lastMessage = lastMessage
                    }
                case .failure(let error):
                    self?.errorTitle = "Error al obtener mensajes"
                    self?.errorMessage = "Hubo un error al intentar obtener los mensajes. Por favor, inténtalo más tarde."
                    print(error.localizedDescription)
                    self?.showError = true
                }
            }
    }
    
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
    
    func checkIfMessageWasSentByCurrentUser(_ message: MessageModel) -> Bool {
        return message.senderUserID == Auth.auth().currentUser?.uid
    }
}
