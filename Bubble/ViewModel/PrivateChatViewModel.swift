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
    var lastMessage: MessageModel = .init(senderUserID: "", content: "", timestamp: .init(), type: MessageType.text)

    /// Agrupa los mensajes por fecha y los ordena cronológicamente.
    ///
    /// - Returns: Un array de tuplas donde la clave es la fecha (`Date`) y el valor es una lista de mensajes (`[MessageModel]`).
    var groupedMessages: [(key: Date, value: [MessageModel])] {
        let calendar = Calendar.current
        let sortedMessages = messages.sorted { $0.timestamp.dateValue() < $1.timestamp.dateValue() }
        let groups = Dictionary(grouping: sortedMessages) { message in
            calendar.startOfDay(for: message.timestamp.dateValue())
        }

        return groups.sorted { $0.key < $1.key }
    }
    
    /// Obtiene los mensajes de un chat privado y los ordena por timestamp.
    ///
    /// - Parameter chatID: El identificador del chat del cual se desean obtener los mensajes.
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
    
    /// Función que formatea la fecha de cabecera para cada grupo.
    /// - Parameter date: La fecha correspondiente al grupo de mensajes.
    /// - Returns: Un String formateado: "Hoy", "Ayer" o "dd-MM-yyyy".
    func dateHeader(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            return formatter.string(from: date)
        }
    }
    
    /// Formatea un `Timestamp` de Firebase en una cadena de hora en formato `HH:mm`.
    ///
    /// - Parameter timestamp: El `Timestamp` que se desea formatear.
    /// - Returns: Una cadena con la hora en formato `HH:mm`.
    func formatTime(from timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
