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

@Observable @MainActor
class PublicChatViewModel {
    private let publicChatService = PublicChatService()
    
    var messages: [MessageModel] = []
    var visibleUsers: [UserModel] = []
    var userColors: [String: Color] = [:]
    var errorTitle: String = ""
    var errorMessage: String = ""
    var showError: Bool = false

    /// Obtiene los mensajes del chat público en tiempo real.
    func fetchPublicChatMessages() {
        Task{
            do{
                for try await messages in await publicChatService.fetchPublicChatMessages(){
                    self.messages = messages
                }
            }catch{
                self.errorTitle = "Mensajes no encontrados"
                self.errorMessage = "Error al obtener mensajes del chat público."
                self.showError = true
            }
        }
    }
    
    /// Envía un mensaje al chat público.
    /// - Parameter text: Contenido del mensaje a enviar.
    func sendPublicMessage(_ text: String) async {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorTitle = "Error: sin usuarios"
            errorMessage = "No hay usuario autenticado."
            showError = true
            return
        }
        
        let message = MessageModel(id: UUID().uuidString,
                                   senderUserID: userID,
                                   content: text,
                                   timestamp: Timestamp(),
                                   type: .text)
        
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
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.gray)
        }
    }
    
}
