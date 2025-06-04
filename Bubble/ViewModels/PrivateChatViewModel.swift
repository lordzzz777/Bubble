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
import SwiftUI
import UniformTypeIdentifiers
import Kingfisher

enum ChatParticipantRiole {
    case me(UserModel)
    case friend(UserModel)
}

@Observable @MainActor
class PrivateChatViewModel {
    
    private let privateChatService: PrivateChatService = PrivateChatService()
    
    var user: UserModel?
    var me: UserModel?
    var friendUser: UserModel?
    
    var chats: [ChatModel] = []
    var messages: [MessageModel] = []
    var showError: Bool = false
    var showAddFriendView: Bool = false
    
    var friendStatus: FriendRequestStatus = .none
    
    var searchQuery = "" // Variables para la búsqueda
    var errorTitle: String = ""
    var errorMessage: String = ""
    var lastMessage: MessageModel = .init(
        senderUserID: "",
        content: "",
        timestamp: .init(),
        type: MessageType.text
    )
    
    // Tareas de escucha
    private var chatTask: Task<Void, Never>?
    private var publicChatTask: Task<Void, Never>?
    private var userTask: Task<Void, Never>?
    
    /// Caché en memoria de los amigos ya descargados (clave = userID).
    private var usersCache: [String: UserModel] = [:]
    
    init(){
        Task{
           await laadCurrentUser()
        }
    }
    
    ///Cargar mi usuario al iniciar la app
    private func laadCurrentUser() async {
        guard let uid = Auth.auth().currentUser?.uid else {return}
        
        do{
            self.me = try await privateChatService.getUserOnce(by: uid)
        }catch{
            print("Error: no puedo cargar mi proìo usuario")
        }
    }
    
    /// Agrupa los mensajes por fecha y los ordena cronológicamente.
    ///
    /// - Returns: Un array de tuplas donde la clave es la fecha (`Date`)
    /// y el valor es una lista de mensajes (`[MessageModel]`).
    var groupedMessages: [(key: Date, value: [MessageModel])] {
        let calendar = Calendar.current
        let sortedMessages = messages.sorted { $0.timestamp.dateValue() < $1.timestamp.dateValue() }
        let groups = Dictionary(grouping: sortedMessages) { message in
            calendar.startOfDay(for: message.timestamp.dateValue())
        }
        
        return groups.sorted { $0.key < $1.key }
    }
    
    /// Devuelve los chats que coinciden con la búsqueda del usuario.
    var filteredChats: [ChatModel] {
        let query = searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        guard query.isEmpty == false else { return chats }
        
        return chats.filter { chat in
            // 1. Coincidencia en el último mensaje
            if chat.lastMessage.lowercased().contains(query) { return true }
            
            // 2. Coincidencia en el nombre del amigo
            if let name = friendDisplayName(for: chat),
               name.contains(query) {
                return true
            }
            return false
        }
    }

    /// Comprueba si el usuario con `userID` ya es amigo del usuario actual.
    ///
    /// - Hace la llamada a `PrivateChatService.checkIfFriend`.
    /// - Si la respuesta es `true` → actualiza `friendStatus` a `.accepted`.
    /// - Si hay un error → muestra alerta mediante `errorTitle/errorMessage`.
    ///
    /// El método está `async` porque depende de Firestore.
    ///
    /// - Parameter userID: Identificador del posible amigo.
    func checkIfUserIsFriend(userID: String) async  {
        do {
            let areUserFriends = try await privateChatService.checkIfFriend(friendID: userID)
            print("areUserFriends: \(areUserFriends)")
            if areUserFriends {
                friendStatus = .accepted
            }
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
    func fetchChats() async {
        
        chatTask?.cancel()
        
        chatTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            
            do {
                for try await chatsSnapshot in await privateChatService.getChats() {
                    guard !Task.isCancelled else { return }
                    
                    // 1. Ordena los chats
                    let ordered = chatsSnapshot.sorted {
                        $0.lastMessageTimestamp.seconds > $1.lastMessageTimestamp.seconds
                    }
                    
                    // 2. Prefetch concurrente de *todos* los participantes
                    await withTaskGroup(of: Void.self) { group in
                        for chat in ordered {
                            for id in chat.participants {
                                
                                // !! usa `continue`, no `return`
                                guard usersCache[id] == nil else { continue }
                                
                                group.addTask { [weak self] in
                                    guard let self else { return }
                                    do {
                                        if let u = try await self.privateChatService.getUserOnce(by: id) {
                                            await MainActor.run {
                                                self.usersCache[id] = u
                                            }
                                        }
                                    } catch {
                                        print(" !No se pudo precargar usuario \(id): \(error)")
                                    }
                                }
                            }
                        }
                    }
                    
                    // 3. Actualiza la lista de chats en el hilo principal
                    await MainActor.run { self.chats = ordered }
                }
                
            } catch {
                await MainActor.run {
                    self.errorTitle   = "Error al obtener los chats"
                    self.errorMessage = "Ocurrió un error desconocido al obtener los chats, inténtalo más tarde."
                    self.showError    = true
                }
            }
        }
    }

    /// Devuelve el `UserModel` asociado al `id` recibido.
    /// - Parameter id: Identificador del usuario que se busca.
    /// - Returns: El modelo si está en caché o si coincide con el usuario actual.
    func userModel(for id: String) -> UserModel? {
        return usersCache[id] ?? (id == user?.id ? user : nil)
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
    
    /// Nombre (en minúsculas) del otro participante, si está en caché.
    private func friendDisplayName(for chat: ChatModel) -> String? {
        let friendID = getFriendID(chat.participants)
        return usersCache[friendID]?.nickname.lowercased()
    }
    
    /// Edita un mensaje en Firestore.
    func editMessage(chatsID: String, messageID: String, newCountent: String) async throws {
        do{
            try await privateChatService.editMessage(chatsID: chatsID, messageID: messageID, newContent: newCountent)
        }catch{
            errorTitle = "Error al eliminar"
            errorMessage = "No se pudo marcar como eliminado."
            showError = true
            
            print("Error desde el ViewModel -> no se ha podido editart: ")
            throw error
        }
    }
    
    /// Marca un mensaje como eliminado (edita el contenido).
    func deleteMessageMark(chatsID: String, messageID: String) async throws {
        
        do{
            try await privateChatService.deleteMessage(chatID: chatsID, messageID: messageID)
            
        }catch{
            errorTitle = "Error marcar eliminar"
            errorMessage = "No se pudo marcar como eliminado."
            showError = true
            
            print("Error desde el ViewModel -> no se ha podido marcar como eliminado: ")
            throw error
        }
    }
    
    /// Elimina permanentemente un mensaje de Firestore.
    private func permanentlyDeleteMessage(chatsID: String, messageID: String) async throws {
        do{
            try await privateChatService.permanentlyDeleteMessage(chatID: chatsID, messageID: messageID)
        }catch{
            errorTitle = "Error al eliminar"
            errorMessage = "No se pudo eliminado el mensaje."
            showError = true
            
            print("Error desde el ViewModel -> no se ha podido eliminado el mensaje: ")
            throw error
        }
    }
    
    /// Elimina permanentemente en Firestore los mensajes que llevan
    /// cierto tiempo marcados como "Mensaje eliminado".
    ///
    /// - Parameters:
    ///   - chatID:  ID del chat al que pertenecen los mensajes.
    ///   - seconds: Tiempo (en segundos) que debe haber transcurrido desde
    ///              que se marcaron como eliminados para borrarlos.
    ///              Valor por defecto: 3600 seg = 1 hora.
    func cleanUpDeletedMessages(chatID: String, olderThan seconds: TimeInterval = 3600) async {
    let cutoffDate = Date().addingTimeInterval(-seconds)
    
    // 1. Filtra los mensajes marcados como borrados y antiguos
    let deletable = messages.filter {
        $0.content == "Mensaje eliminado" &&
        $0.timestamp.dateValue() < cutoffDate
    }
    
    // 2. Elimina cada uno en Firestore
    for msg in deletable {
        try? await permanentlyDeleteMessage(chatsID: chatID, messageID: msg.id)
    }
 }
    
    /// Envía un mensaje privado en un chat determinado, incluyendo opcionalmente información de respuesta.
    ///
    /// - Parameters:
    ///   - chatID: El identificador único del chat donde se enviará el mensaje.
    ///   - messageText: El contenido textual del mensaje a enviar.
    ///   - replyingToMessageID: (Opcional) El ID del mensaje al que se está respondiendo.
    ///   - replyingToText: (Opcional) El contenido del mensaje al que se responde, para mostrar referencia visual.
    ///   - replyingToNickname: (Opcional) El nickname del autor del mensaje al que se responde.
    ///
    /// Este método crea una instancia de `MessageModel`, la envía a Firestore mediante `sendAdvancedMessage`,
    /// y actualiza el estado local con `lastMessage` para permitir scroll automático u otras reacciones en la interfaz.
    func sendPrivateMessage(
        chatID: String,
        messageText: String,
        replyingToMessageID: String? = nil,
        replyingToText: String? = nil,
        replyingToNickname: String? = nil
    ) async{
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let message = MessageModel(
            id: UUID().uuidString,
            senderUserID: userID,
            content: messageText,
            timestamp: Timestamp(date: .now),
            type: .text,
            replyToMessageID: replyingToMessageID,
            replyingToText: replyingToText,
            replyingToNickname: replyingToNickname
        )
        
        do {
            try await privateChatService.sendAdvancedMessage(chatID: chatID, message: message)
            lastMessage = message
        } catch {
            showError = true
            errorTitle = "Error"
            errorMessage = "No se pudo enviar el mensaje."
        }
    }
    
    /// Indica si hay que mostrar el avatar junto al mensaje actual.
    /// - Parameters:
    ///   - currentMessage: Mensaje que se está dibujando.
    ///   - messages: Array completo de mensajes (ordenados de antiguo → nuevo).
    /// - Returns: `true` si el avatar debe mostrarse.
    func shouldShowAvatar(currentMessage: MessageModel, in messages: [MessageModel]) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == currentMessage.id }) else {
            return true
        }
        if index + 1 >= messages.count {
            return true
        }
        let nextMessage = messages[index + 1]
        return currentMessage.senderUserID != nextMessage.senderUserID
    }
    
    /// Agrega una reacción (emoji) a un mensaje en el chat público.
    ///
    /// - Parameters:
    ///   - chatsID: El ID del mensaje al que se quiere reaccionar.
    ///   - emoji: El emoji que se va a agregar como reacción.
    ///   - userID: El ID del usuario que reacciona (aunque no se usa porque se obtiene desde Firebase).
    func addReacToMessage(chatsID: String, messageID:String, emoji: String, userID: String) async {
        guard let userID = Auth.auth().currentUser?.uid else {return}
        
        do{
            try await privateChatService.reactToMessage(chatsID: chatsID, messageID: messageID, emoji: emoji, userID: userID)
            
        }catch{
            errorTitle = "Error al reaccionar"
            errorMessage = "No se pudo enviar la reacción."
            showError = true
        }
    }
    
    /// Elimina la reacción de un mensaje para el usuario actual.
    ///
    /// - Parameter messageID: El ID del mensaje del cual se quiere quitar la reacción.
    func reacToMessageRemove(from chatsID: String, messageID: String) async {
        guard let userID = Auth.auth().currentUser?.uid else {return}
        
        do{
            try await privateChatService.removeReaction(fromChatsIDID: chatsID, messageID: messageID, userID: userID)
        }catch{
            errorTitle = "Error"
            errorMessage = "No se pudo eliminar la reacción."
            showError = true
        }
    }
    
    /// Maneja el envío o la edición de un mensaje desde la vista, centralizando toda la lógica en el ViewModel.
    func sendText(
        in chatID: String,
        text: String,
        isEditing: Bool,
        editingMessageID: String?,
        replyingToMessageID: String?,
        replyingToNickname: String?
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return}
        
        if isEditing, let id = editingMessageID{
            do{
               try await editMessage(chatsID: chatID, messageID: id, newCountent: trimmed)
            }catch{
                print("Error des de ViewModel: error al editar mensaje")
            }
        }else{
            let original = messages.first { $0.id == replyingToMessageID}?.content
            await sendPrivateMessage(
                chatID:              chatID,
                messageText:         trimmed,
                replyingToMessageID: replyingToMessageID,
                replyingToText:      original,
                replyingToNickname:  replyingToNickname
            )
        }
    }
    
    /// Copia un texto, y cualquier fomato de archivo
    /// al portapapeles y muestra un toast por 2 segundos.
    ///
    /// - Parameters:
    ///   - message: cualquier formato de archivo y texto.
    ///   - isCopiedToast: Binding a una variable `@State` en la vista que controla la visibilidad del toast.
    func privateCopyToClopboard(_ message: Any?, _ isCopiedToast:Binding<Bool>) async {
        guard let message = message else {return}
        let pasted = UIPasteboard.general
        switch message{
            
        case let stri as String:
            pasted.string = stri
            
        case let img as UIImage:
            if let data = img.pngData(){
                pasted.setData(data, forPasteboardType: UTType.png.identifier)
            }
            
        case let url as URL:
            if url.isFileURL { // ↳ fichero local
                guard FileManager.default.fileExists(atPath: url.path) else { return }
                pasted.setItems([[UTType.fileURL.identifier: url]], options: [:])
            } else {  // ↳ remota http/https
                do{
                    let (data, _) = try await URLSession.shared.data(from: url)
                    
                    if let imageData = UIImage(data: data), let png = imageData.pngData(){
                        pasted.setData(png, forPasteboardType: UTType.png.identifier)
                    }else{
                        pasted.string = url.absoluteString
                    }
                }catch{
                    pasted.string = url.absoluteString
                }
            }
            
        default:
            print("Error archivo no soportado")
            return
        }
        
        isCopiedToast.wrappedValue = true
        
        do{
            try await Task.sleep(nanoseconds: 2_000_000_000)
            isCopiedToast.wrappedValue = false
        }catch{
            print("Error en la espera del toast")
        }
    }
}
