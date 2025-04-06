//
//  PrivateChatViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore

@Observable @MainActor
class PrivateChatViewModel {
    
    private let privateChatService: PrivateChatService = PrivateChatService()
    
    var user: UserModel?
    var chats: [ChatModel] = []
    var messages: [MessageModel] = []
    var areUserFriends: Bool = false
    var showError: Bool = false
    var showAddFriendView: Bool = false
    
    var searchQuery = "" // Variables para la búsqueda
    var errorTitle: String = ""
    var errorMessage: String = ""
    var lastMessage: MessageModel = .init(senderUserID: "", content: "", timestamp: .init(), type: MessageType.text)

    // Tareas de escucha
    private var chatTask: Task<Void, Never>?
    private var publicChatTask: Task<Void, Never>?
    private var userTask: Task<Void, Never>?
    
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
    
    func checkIfUserIsFriend() async  {
        do {
            areUserFriends = try await privateChatService.checkIfFriend(friendID: user?.id ?? "")
        } catch {
            errorTitle = "Error"
            errorMessage = "Ocurrió un error al verificar si el usuario es amigo."
            showError = true
        }
    }
    
    /// Obtiene los mensajes de un chat privado y los ordena por timestamp.
    ///
    /// - Parameter chatID: El identificador del chat del cual se desean obtener los mensajes.
    func fetchMessages(chatID: String) async {
        do {
            for try await newMessages in await privateChatService.fetchMessagesFromChat(chatID: chatID) {
                messages = newMessages.sorted(by: { $0.timestamp.seconds < $1.timestamp.seconds })
                if let last = messages.last {
                    lastMessage = last
                }
            }
        } catch {
            errorTitle = "Error al obtener mensajes"
            errorMessage = "Hubo un error al intentar obtener los mensajes. Por favor, inténtalo más tarde."
            print(error.localizedDescription)
            showError = true
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
    
    /// Formatea un `Timestamp` de Firebase en una cadena legible según su antigüedad.
    ///
    /// - Parameter timestamp: El `Timestamp` del mensaje.
    /// - Returns: Una cadena formateada con la fecha y la hora en diferentes estilos según la antigüedad del mensaje.
    func formatMessageTimestamp(_ timestamp: Timestamp) -> String {
        let messageDate = timestamp.dateValue()
        let calendar = Calendar.current
        
        // Formateador para la hora: "HH:mm"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: messageDate)
        
        if calendar.isDateInToday(messageDate) {
            return "\(timeString)"
        } else if calendar.isDateInYesterday(messageDate) {
            return "Ayer \n\(timeString)"
        } else {
            // Formateador para fecha completa: "dd-MM-yyyy HH:mm"
            let fullFormatter = DateFormatter()
            fullFormatter.dateFormat = "dd-MM-yy \nHH:mm"
            return fullFormatter.string(from: messageDate)
        }
    }
    
    /// Obtiene el ID del amigo dentro de una lista de IDs, excluyendo el del usuario actual.
    /// - Parameter ids: Un array de Strings que contiene los IDs de los participantes.
    /// - Returns: El ID del amigo si se encuentra, de lo contrario, una cadena vacía.
    func getFriendID(_ ids: [String]) -> String {
        let currentUserID = Auth.auth().currentUser?.uid ?? ""
        
        //Buscar el primer ID que NO sea el del usuario actual
        for id in ids {
            if id != currentUserID {
                return id //Retorna el ID del amigo
            }
        }
        if let friendID = ids.first{
            return friendID
        }
        
        return "El amigo no ha sido encontrado ..."
    }
    
    /// Obtiene el ID del amigo en un chat de dos participantes.
    ///
    /// - Parameter participants: Lista de identificadores de los participantes del chat.
    /// - Returns: El ID del amigo (el participante que no es el usuario actual). Si no se encuentra, devuelve una cadena vacía.
    func getFriendID(participants: [String]) -> String {
        return participants.filter { $0 != Auth.auth().currentUser?.uid ?? "" }.first ?? ""
    }
    
    /// Verifica si un mensaje fue enviado por el usuario autenticado.
    ///
    /// - Parameter senderUserID: El ID del usuario que envió el mensaje.
    /// - Returns: `true` si el mensaje fue enviado por el usuario autenticado, `false` en caso contrario.
    func checkIfMessageWasSentByCurrentUser(senderUserID: String) -> Bool {
        return senderUserID == Auth.auth().currentUser?.uid
    }
    
    /// Detiene la escucha de actualizaciones en tiempo real de los chats y el usuario.
    /// Cancela cualquier tarea activa y libera los recursos asociados.
    func stopListening() {
        Task {@MainActor in
            chatTask?.cancel()
            userTask?.cancel()
            chatTask = nil
            userTask = nil
        }
    }
    
    /// Elimina un chat específico tanto de Firestore como de la lista local de chats en el ViewModel.
    /// - Parameter chatID: El ID del chat que se desea eliminar.
    func deleteChat(chatID: String){
        Task {  [weak self] in
            guard let self = self else {return}
            do {
                try await privateChatService.deleteChat(chatID: chatID)
                self.chats.removeAll{$0.id == chatID}
                
            } catch {
                self.errorTitle = "Error"
                self.errorMessage = "El chat no se ha podido eliminar, intentelo mas tarde"
                self.showError = true
            }
        }
    }
    
    /// Obtiene la lista de chats en los que el usuario participa y los almacena en la variable `chats`.
    /// Esta función escucha cambios en tiempo real.
    /// - Note: Cancela cualquier tarea en ejecución antes de iniciar una nueva.
    func fetchChats() async{
        chatTask?.cancel()
        
        chatTask = Task {[weak self] in
            guard let self = self else {return}
            do{
                for try await chat in await privateChatService.getChats(){
                    guard !Task.isCancelled else { return }
                    self.chats = chat
                    self.chats = self.chats.sorted(by: { $0.lastMessageTimestamp.seconds > $1.lastMessageTimestamp.seconds })
                }
                
            }catch{
                self.errorTitle = "Error al obtener los chats"
                self.errorMessage = "Ocurrió un error desconocido al obtener los chas, intentelo mas tarde"
                self.showError = true
            }
        }
        
    }
    
    /// Obtiene la información de un usuario en tiempo real y la almacena en la variable `user`.
    /// - Parameter userID: El ID del usuario que se desea obtener.
    func fetchUser(chat: ChatModel) {
        userTask?.cancel()
        userTask = Task { [weak self] in
            guard let self = self else {return}
            do {
                if chat.participants.count < 2 {
                    for try await user in await privateChatService.getUser(by: chat.lastMessageSenderUserID) {
                        guard !Task.isCancelled else { return }
                        self.user = user
                    }
                } else {
                    let friendUID = getFriendID(chat.participants)
                    for try await user in await privateChatService.getUser(by: friendUID) {
                        guard !Task.isCancelled else { return }
                        self.user = user
                    }
                }
            } catch {
                self.errorTitle = "Error al traerte el usuario"
                self.errorMessage = "Ocurrió un error por el cual no se apodido mostrar el ususrio intentelo mas tarde"
                self.showError = true
            }
        }
    }
}
