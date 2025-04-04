//
//  PublicChatViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 16/3/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import Kingfisher

@Observable @MainActor
class PublicChatViewModel {
    private let publicChatService = PublicChatService()
    
    var messages: [MessageModel] = []
    var visibleUsers: [UserModel] = []
    var userColors: [String: Color] = [:]
    var errorTitle: String = ""
    var errorMessage: String = ""
    var replyNotificationsCount: Int = 0
    var showError: Bool = false
    var isPublicChatVisible: Bool = false
    
    /// Obtiene los mensajes del chat público en tiempo real.
    func fetchPublicChatMessages() {
        Task {
            do {
                for try await messages in await publicChatService.fetchPublicChatMessages() {
                    self.messages = messages
                    
                    guard let currentUserID = Auth.auth().currentUser?.uid,
                          let currentUser = visibleUsers.first(where: { $0.id == currentUserID }) else { return }
                    
                    let lastSeenID = UserDefaults.standard.string(forKey: "lastSeenReplyID")
                    
                    // Filtrar respuestas que no son del propio usuario
                    let repliesToMe = messages.filter {
                        $0.replyingToNickname == currentUser.nickname &&
                        $0.senderUserID != currentUserID
                    }
                    
                    // Comparar con el último mensaje visto
                    if let lastSeenID = lastSeenID,
                       let index = repliesToMe.lastIndex(where: { $0.id == lastSeenID }) {
                        let newReplies = repliesToMe.suffix(from: repliesToMe.index(after: index))
                        self.replyNotificationsCount = isPublicChatVisible ? 0 : newReplies.count
                    } else {
                        self.replyNotificationsCount = isPublicChatVisible ? 0 : repliesToMe.count
                    }
                }
            } catch {
                self.errorTitle = "Mensajes no encontrados"
                self.errorMessage = "Error al obtener mensajes del chat público."
                self.showError = true
            }
        }
    }
    
    /// Envía un mensaje al chat público.
    /// - Parameter text: Contenido del mensaje a enviar.
    func sendPublicMessage(_ text: String, replyingTo messageID: String?) async {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorTitle = "Error: sin usuarios"
            errorMessage = "No hay usuario autenticado."
            showError = true
            return
        }
        var replyingToText: String? = nil
        var replyingToNickname: String? = nil
        
        // Buscar texto y nickname del mensaje al que se responde
        if let replyID = messageID,
           let repliedMessage = messages.first(where: { $0.id == replyID }),
           let repliedUser = visibleUsers.first(where: { $0.id == repliedMessage.senderUserID }) {
            replyingToText = repliedMessage.content
            replyingToNickname = repliedUser.nickname
        }
        
        let message = MessageModel(id: UUID().uuidString,
                                   senderUserID: userID,
                                   content: text,
                                   timestamp: Timestamp(),
                                   type: .text,
                                   replyToMessageID: messageID,
                                   replyingToText: replyingToText,
                                   replyingToNickname: replyingToNickname )
        
        do{
            try await publicChatService.sendPublicMessage(message)
            
        }catch{
            errorTitle = "Error, no hay mesaje"
            errorMessage = "Error al enviar mensaje público."
            showError = true
        }
    }
    
    /// Edita un mensaje en Firestore.
    func editMessage(messageID: String, newContent: String) async {
        do{
            try await publicChatService.editMessage(messageID: messageID, newContent: newContent)
        }catch{
            errorTitle = "Error al eliminar"
            errorMessage = "No se pudo marcar como eliminado."
            showError = true
        }
    }
    
    /// Marca un mensaje como eliminado (edita el contenido).
    func deleteMessage(messageID: String) async{
        do{
            try await publicChatService.deleteMessage(messageID: messageID)
        }catch{
            errorTitle = "Error al eliminar"
            errorMessage = "No se pudo marcar como eliminado."
            showError = true
        }
    }
    
    /// Elimina permanentemente un mensaje de Firestore.
    func permanentlyDeleteMessage(messageID: String) async {
        do{
            try await publicChatService.permanentlyDeleteMessage(messageID: messageID)
        }catch{
            errorTitle = "Error al eliminar"
            errorMessage = "No se pudo eliminar el mensaje."
            showError = true
        }
    }
    
    /// Obtiene todos los usuarios visibles en Firestore.
    func fetchVisibleUsers() async {
        do{
            visibleUsers = try await publicChatService.fetchVisibleUsers()
            assignColorsToUsers()
        }catch{
            errorTitle = "Error, no hay usuario"
            errorMessage = "Error al obtener usuarios"
            showError = true
        }
    }
    
    /// Asigna un color único a cada usuario visible de forma
    /// dinámica según la cantidad de participantes.
    func assignColorsToUsers() {
        userColors.removeAll()
        
        for (index, user) in visibleUsers.enumerated(){
            let hue = Double(index) / Double(visibleUsers.count)
            let color = Color(hue: hue, saturation: 0.7, brightness: 0.9)
            userColors[user.id] = color
        }
    }
    
    /// Obtiene el color asignado a un usuario dado su ID.
    /// - Returns: Color asignado o gris por defecto.
    func getColorForUser(userID: String) -> Color {
        return userColors[userID] ?? .green
    }
    
    /// Formatea un `Timestamp` de Firebase en una cadena legible según su antigüedad.
    ///
    /// - Parameter timestamp: El `Timestamp` del mensaje.
    /// - Returns: Una cadena formateada con la fecha y la hora en diferentes estilos según la antigüedad del mensaje.
    func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    /// Ajusta la altura del `TextField` dinámicamente según el texto
    func updateHeight(messageText: String, textFieldHeight: Binding<CGFloat>){
        
        let maxHeight: CGFloat = 120
        let lineHeight: CGFloat = 20
        let numLines = CGFloat(messageText.split(separator: "\n").count)
        
        textFieldHeight.wrappedValue = min(40 + (numLines * lineHeight), maxHeight)
    }
    
    /// Devuelve la imagen de avatar del usuario
    @ViewBuilder
    func profileImage(_ user: UserModel?) -> some View {
        if let imageURL = user?.imgUrl, let url = URL(string: imageURL) {
            KFImage(url).resizable().scaledToFill()
                .progressViewStyle(.automatic)
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.gray)
        }
    }
    
    /// Maneja el envío o la edición de un mensaje desde la vista, centralizando toda la lógica en el ViewModel.
    func handleSendOrEdit(
        messageText: Binding<String>,
        editingMessageID: Binding<String?>,
        textFieldHeight: Binding<CGFloat>,
        isEditing: Binding<Bool>,
        replyingToMessageID: Binding<String?>
    ) async {
        let trimmedText = messageText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        if let messageID = editingMessageID.wrappedValue {
            await editMessage(messageID: messageID, newContent: trimmedText)
            isEditing.wrappedValue = false
            editingMessageID.wrappedValue = nil
        } else {
            await sendPublicMessage(trimmedText, replyingTo: replyingToMessageID.wrappedValue)
            replyingToMessageID.wrappedValue = nil // Limpiar después de enviar
        }
        
        if isPublicChatVisible,
           let currentUserID = Auth.auth().currentUser?.uid,
           let currentUser = visibleUsers.first(where: { $0.id == currentUserID }),
           let lastReply = messages.filter({ $0.replyingToNickname == currentUser.nickname }).last {
            
            UserDefaults.standard.set(lastReply.id, forKey: "lastSeenReplyID")
        }
        
        messageText.wrappedValue = ""
        textFieldHeight.wrappedValue = 40
    }
    
    /// Restablece (pone en cero) las notificaciones de respuestas dirigidas al usuario actual,
    /// y guarda el último mensaje que le respondió en UserDefaults para referencia futura.
    ///
    /// Esta función se llama cuando el usuario entra al chat público, indicando que ya vio las respuestas.
    func resetReplyNotificationsIfNeeded() async {
        if let currentUserID = Auth.auth().currentUser?.uid,
           let currentUser = visibleUsers.first(where: { $0.id == currentUserID }) {
            
            if let lastReply = messages
                .filter({ $0.replyingToNickname == currentUser.nickname && $0.senderUserID != currentUserID })
                .last {
                UserDefaults.standard.set(lastReply.id, forKey: "lastSeenReplyID")
            }
            
            replyNotificationsCount = 0
        }
    }
    
    /// Carga desde UserDefaults el ID del último mensaje que fue una respuesta dirigida al usuario
    /// y que el usuario ya ha visto previamente.
    ///
    /// - Returns: Un `String` opcional que representa el ID del último mensaje respondido visto,
    /// o `nil` si no se ha guardado ninguno.
    func loadLastSeenReplyID() -> String? {
        return UserDefaults.standard.string(forKey: "lastSeenReplyID")
    }
    
    /// Elimina permanentemente los mensajes que fueron marcados como "Mensaje eliminado"
    /// y que son más antiguos que el tiempo especificado.
    ///
    /// - Parameter seconds: Tiempo en segundos que define qué tan viejo debe ser un mensaje eliminado
    /// para ser eliminado de Firestore. Por defecto: 1 hora (3600 segundos).
    func cleanUpDeletedMessages(olderThan seconds: TimeInterval = 3600) async {
        let cutoffDate = Date().addingTimeInterval(-seconds)
        
        let deletedMessages = messages.filter {
            $0.content == "Mensaje eliminado" && $0.timestamp.dateValue() < cutoffDate
        }
        
        for message in deletedMessages {
            await permanentlyDeleteMessage(messageID: message.id)
        }
    }
    
    /// Agrega una reacción (emoji) a un mensaje en el chat público.
    ///
    /// - Parameters:
    ///   - messageID: El ID del mensaje al que se quiere reaccionar.
    ///   - emoji: El emoji que se va a agregar como reacción.
    ///   - userID: El ID del usuario que reacciona (aunque no se usa porque se obtiene desde Firebase).
    func addReacToMessage(messageID: String, emoji: String, userID: String) async {
        guard let userID = Auth.auth().currentUser?.uid else {return}
        
        do{
            try await publicChatService.reactToMessage(messageID: messageID, emoji: emoji, userID: userID)
            
        }catch{
            errorTitle = "Error al reaccionar"
            errorMessage = "No se pudo enviar la reacción."
            showError = true
        }
    }
    
    /// Elimina la reacción de un mensaje para el usuario actual.
    ///
    /// - Parameter messageID: El ID del mensaje del cual se quiere quitar la reacción.
    func reacToMessageRemove(from messageID: String) async {
        guard let userID = Auth.auth().currentUser?.uid else {return}
        
        do{
            try await publicChatService.removeReaction(fromMessageID: messageID, userID: userID)
        }catch{
            errorTitle = "Error"
            errorMessage = "No se pudo eliminar la reacción."
            showError = true
        }
    }
    
    /// Copia un texto al portapapeles y muestra un toast por 2 segundos.
    ///
    /// - Parameters:
    ///   - text: El texto que se va a copiar al portapapeles.
    ///   - showCopiedToast: Binding a una variable `@State` en la vista que controla la visibilidad del toast.
    func copyToClopboard(_ text: String,_ showCopiedToast: Binding<Bool>) async {
        
        UIPasteboard.general.string = text
        showCopiedToast.wrappedValue = true
        
        do{
            try await Task.sleep(nanoseconds: 2_000_000_000)
            showCopiedToast.wrappedValue = false
        }catch{
            print("Error en la espera del toast")
        }
    }
}
