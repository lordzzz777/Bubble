//
//  PrivateChatViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import Foundation
import FirebaseAuth

@Observable
class PrivateChatViewModel {
    private let privateChatServide: PrivateChatService = PrivateChatService()
    var messages: [MessageModel] = []
    var showError: Bool = false
    var errorTitle: String = ""
    var errorMessage: String = ""
    
    func fetchMessages(chatID: String) {
         privateChatServide.fetchMessagesFromChat(chatID: chatID) { [weak self] result in
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
    
    
    func checkIfMessageWasSentByCurrentUser(_ message: MessageModel) -> Bool {
        return message.senderUserID == Auth.auth().currentUser?.uid
    }
}
