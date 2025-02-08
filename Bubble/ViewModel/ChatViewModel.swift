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

@Observable
class ChatViewModel{

    private var userService = ChatsService()
    private var firestoreService = FirestoreService()
   
    var user: UserModel?
    var chats: [ChatModel] = []
    var messages: [MessageModel] = []
    private var chatTask: Task<Void, Never>?
    private var userTask: Task<Void, Never>?
    
    let visibilityOptions = ["privado", "Publico"]
    var selectedVisibility = "privado"
    var searchText = ""
    var errorTitle = ""
    var errorDescription = ""
    var successMessasTitle = ""
    var successMessasDescription = ""
    
    var isMessageDestructive = false
    var isfetchChatsError = false
    var isSuccessMessas = false
    var isWiffi = false
    
    
    
    @MainActor func fetchUser (userID: String) {
        userTask?.cancel()
        userTask = Task {
            do{
                for try await user in await userService.getUser(by: userID){
                    self.user = user
                }
            }catch{
                self.errorTitle = "Error al traerte el usuario"
                self.errorDescription = "Ocurrió un error por el cual no se apodido mostrar el ususrio intentelo mas tarde"
                self.isfetchChatsError = true
            }
        }
    }
    
    @MainActor     // Método para obtener los chats en tiempo real
    func fetchChats() {
        chatTask?.cancel() // Evitar múltiples suscripciones
        chatTask = Task {
            do{
                for try await chats in try await userService.getChats(){
                    await MainActor.run {
                        self.chats = chats
                    }
                }
            }catch{
                await MainActor.run(body: {
                    self.errorTitle = ""
                })
            }
        }
    }
    
    @MainActor func deleteChat(chatID: String){
       Task {
            do{
                try await userService.deleteChat(chatID: chatID)
                self.chats.removeAll{$0.id == chatID}
                
            }catch {
                self.errorTitle = "Error"
                self.errorDescription = "El chat no se ha podido eliminar, intentelo mas tarde"
                self.isfetchChatsError = true
            }
        }
    }
    
//    @MainActor func deleteChatsAll(){
//        Task{
//            do{
//                try await userService.deleteAllChatsForUser(uiD: userService.uid)
//            }catch {
//                self.errorTitle = "Error"
//                self.errorDescription = "los chats no se ha podido eliminar, intentelo mas tarde"
//                self.isfetchChatsError = true
//            }
//        }
//    }
    
    // Metodo para eliminar un solo chat
//    func deleteChat(chatID: String){
//        userService.deleteChat(chatID: chatID) { [weak self] result in
//            
//            switch result{
//            case .success(_):
//                self?.successMessasTitle = "Exrito"
//                self?.successMessasDescription = "El chat se ha eliminado con exito"
//                self?.isSuccessMessas = true
//                self?.chats.removeAll(where: {$0.id == chatID})
//            case .failure(_):
//                self?.errorTitle = "Error"
//                self?.errorDescription = "El chat no se ha podido eliminar, intentelo mas tarde"
//                self?.isfetchChatsError = true
//            }
//        }
//    }
    

    // Cargar Usuarios
//    @MainActor
//    func fetchUser(userID: String){
//        userService.getUser(by: userID){ [weak self] result in
//            switch result {
//            case .success(let success):
//                self?.user = success
//            case .failure(_):
//                self?.isfetchChatsError = true
//                self?.errorTitle = "Error al traerte el usuario"
//                self?.errorDescription = "Ocurrió un error por el cual no se apodido mostrar el ususrio intentelo mas tarde"
//            }
//        }
//    }
    
//    // Cargar los chats
//    func fetchChats(){
//        userService.fetchChats { [weak self] result in
//            switch result {
//            case .success(let success):
//                self?.chats = success
//            case .failure(_):
//                self?.isfetchChatsError = true
//                self?.errorTitle = "Error al obtener los chats"
//                self?.errorDescription = "Ocurrió un error desconocido al obtener los chas, intentelo mas tarde"
//            }
//        }
//        
//    }
    

//    // Metodo para leliminar todos los chat del usuario
//    func deleteChats(uid: String){
//        userService.deleteAllChatsForUser(uiD: <#String#>, uI: uid){ [weak self] result in
//            
//            switch result{
//            case .success:
//                self?.successMessasTitle = "Exrito"
//                self?.successMessasDescription = "Los chats se ha eliminado con exito"
//                self?.isSuccessMessas = true
//                self?.chats.removeAll(where: {$0.id == uid})
//            case .failure(_):
//                self?.errorTitle = "Error"
//                self?.errorDescription = "Los chats no se ha podido eliminar, intentelo mas tarde"
//                self?.isfetchChatsError = true
//            }
//        }
//    }
    
    // Método para detener la escucha cuando la vista desaparece
    func stopListening() {
        chatTask?.cancel()
        userTask?.cancel()
        chatTask = nil
        userTask = nil
    }
    
    deinit {
        stopListening()
    }
    
    // Obtener el idi del usuario
    func getFriendID(_ ids: [String]) -> String {
        var friendID = ""
        let uID = Auth.auth().currentUser?.uid ?? ""
        ids.forEach { id in
            if id != uID {
                friendID = id
            }
        }
        return friendID
    }
    
    // Formatea Timestamp para combertir en String
    func formatTimestamp(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Formato personalizado
        
        return formatter.string(from: timestamp.dateValue())
    }

}
