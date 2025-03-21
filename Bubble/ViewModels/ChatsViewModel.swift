//
//  ChatViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/2/25.
//

import Foundation
import FirebaseFirestore
import Observation
import FirebaseAuth

@Observable @MainActor
class ChatsViewModel: AddNewFriendViewModel {
    // Servicios
    private var chatsService = ChatsService()
    private var firestoreService = FirestoreService()
    private let chatID = "global_chat"
    private let database = Firestore.firestore()
    
    // Datos del usuario y chats
    var user: UserModel?
    var users:[UserModel] = []
    var messages: [MessageModel] = []
    
    // Tareas de escucha
    private var chatTask: Task<Void, Never>?
    private var publicChatTask: Task<Void, Never>?
    private var userTask: Task<Void, Never>?
    
    // Opciones de visibilidad para los chats
    let visibilityOptions = ["privado", "Publico"]
    var selectedVisibility = "privado"
    
    var searchQuery = "" // Variables para la búsqueda
    var isfetchChatsError = false
    var showAddFriendView: Bool = false
    
    /// Obtiene la información de un usuario en tiempo real y la almacena en la variable `user`.
    /// - Parameter userID: El ID del usuario que se desea obtener.
    func fetchUser(chat: ChatModel) {
        userTask?.cancel()
        userTask = Task { [weak self] in
            guard let self = self else {return}
            do {
                if chat.participants.count < 2 {
                    for try await user in await chatsService.getUser(by: chat.lastMessageSenderUserID) {
                        guard !Task.isCancelled else { return }
                        self.user = user
                        print("friend user: \(String(describing: user?.nickname))")
                    }
                } else {
                    let friendUID = getFriendID(chat.participants)
                    for try await user in await chatsService.getUser(by: friendUID) {
                        guard !Task.isCancelled else { return }
                        self.user = user
                        print("friend user: \(String(describing: user?.nickname))")
                    }
                }
            } catch {
                self.errorTitle = "Error al traerte el usuario"
                self.errorDescription = "Ocurrió un error por el cual no se apodido mostrar el ususrio intentelo mas tarde"
                self.isfetchChatsError = true
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
                for try await chat in chatsService.getChats(){
                    guard !Task.isCancelled else { return }
                    self.chats = chat
                    self.chats = self.chats.sorted(by: { $0.lastMessageTimestamp.seconds > $1.lastMessageTimestamp.seconds })
                }
                
            }catch{
                self.errorTitle = "Error al obtener los chats"
                self.errorDescription = "Ocurrió un error desconocido al obtener los chas, intentelo mas tarde"
                self.isfetchChatsError = true
            }
        }
        
    }
    
    /// Elimina un chat específico tanto de Firestore como de la lista local de chats en el ViewModel.
    /// - Parameter chatID: El ID del chat que se desea eliminar.
     func deleteChat(chatID: String){
       Task {  [weak self] in
           guard let self = self else {return}
            do {
                try await chatsService.deleteChat(chatID: chatID)
                self.chats.removeAll{$0.id == chatID}
                
            } catch {
                self.errorTitle = "Error"
                self.errorDescription = "El chat no se ha podido eliminar, intentelo mas tarde"
                self.isfetchChatsError = true
            }
        }
    }
        
    /// Detiene la escucha de actualizaciones en tiempo real de los chats y el usuario.
    /// Cancela cualquier tarea activa y libera los recursos asociados.
    nonisolated func stopListening() {
        Task {@MainActor in
            chatTask?.cancel()
            userTask?.cancel()
            chatTask = nil
            userTask = nil
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

    /// Convierte un `Timestamp` de Firestore en una cadena de texto con formato de hora.
    /// - Parameter timestamp: El `Timestamp` que se desea formatear.
    /// - Returns: Una cadena de texto con la hora en formato `HH:mm`.
    func formatTimestamp(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Formato personalizado
        
        return formatter.string(from: timestamp.dateValue())
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
    
    /// Escucha en tiempo real los mensajes del chat público y actualiza la lista de mensajes.
    ///
    /// - Nota: Utiliza un `SnapshotListener` para recibir actualizaciones en tiempo real.
    func fetchMessages() {
        database.collection("public_chats").document(chatID)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error al obtener mensajes: \(error?.localizedDescription ?? "Desconocido")")
                    return
                }
                
                self.messages = documents.compactMap { doc in
                    try? doc.data(as: MessageModel.self)
                }
            }
    }
    
    /// Envía un nuevo mensaje al chat público.
    ///
    /// - Parameter text: El contenido del mensaje a enviar.
    func sendMessage(_ text: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let newMessage = MessageModel(
            id: UUID().uuidString,
            senderUserID: userID,
            content: text,
            timestamp: Timestamp(),
            type: .text
        )
        
        database.collection("public_chats").document(chatID)
            .collection("messages")
            .addDocument(data: newMessage.dictionary) { error in
                if let error = error {
                    print("Error al enviar mensaje: \(error.localizedDescription)")
                }
            }
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
}
