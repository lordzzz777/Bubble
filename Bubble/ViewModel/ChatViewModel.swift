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
class ChatViewModel: AddNewFriendViewModel {
    // Servicios
    private var chatsService = ChatsService()
    private var firestoreService = FirestoreService()
   
    // Datos del usuario y chats
    var user: UserModel?
   // var chats: [ChatModel] = []
    var messages: [MessageModel] = []
    
    // Tareas de escucha
    private var chatTask: Task<Void, Never>?
    private var userTask: Task<Void, Never>?
    
    // Opciones de visibilidad para los chats
    let visibilityOptions = ["privado", "Publico"]
    var selectedVisibility = "privado"
    
    var searchQuery = "" // Variables para la búsqueda
   // var errorTitle = ""  // Manejo de errores
   // var errorDescription = ""
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
    func fetchCats() async{
        chatTask?.cancel()
        
        chatTask = Task {[weak self] in
            guard let self = self else {return}
            do{
                for try await chat in chatsService.getChats(){
                    guard !Task.isCancelled else { return }
                    self.chats = chat
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
        return friendID
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

    
    
    func getFriendID(participants: [String]) -> String {
        return participants.filter { $0 != Auth.auth().currentUser?.uid ?? "" }.first ?? ""
    }

}
