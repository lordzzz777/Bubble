//
//  MessageBubbleView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/4/25.
//

import SwiftUI
import FirebaseAuth
import Kingfisher

/// Burbuja de mensaje que ofrece **Editar** y **Eliminar** mediante menú de
/// Poder contestar aun post en especifico ....
/// contexto cuando el autor es el usuario autenticado.
struct MessageBubbleView: View {
    @Environment(PrivateChatViewModel.self) private var privateChatViewModel
    @State private var chatFileViewModel = ChatFileViewModel()
    @State private var chatAudioViewModel = ChatAudioViewModel()
    
    let chatID: String
    var message: MessageModel
    var user: UserModel?
    
    // Bindings recibidos desde `PrivateChatView`
    @Binding var messageText: String
    @Binding var isEditing: Bool
    @Binding var editingMessageID: String?
    @Binding var replyingToMessageID: String?
    @Binding var replyingToNickname: String?
    @Bindable var userProfileView: NewAccountViewModel = .init()
    
    private var isCurrentUser: Bool{
        message.senderUserID == Auth.auth().currentUser?.uid
    }
    
    // Colores para el remitente y el receptor
    private var bubbleColor: Color {
        isCurrentUser ? .green.opacity(0.7) : .cyan.opacity(0.7)
    }
    
   
    
    var body: some View {
        if message.content == "Mensaje eliminado" {
            HStack {
                Spacer()
                Text("\(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? "Tú" : user?.nickname ?? "Usuario") eliminó este mensaje")
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                Spacer()
            }
        }else {
            HStack(alignment: .bottom, spacing: 10) {
                
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: -10) {
                    VStack(alignment: .leading) {
                        //  Nombre del usuario
                        
                        Text(isCurrentUser ? "Tú" : user?.nickname ?? "Usuario")

                            .font(.footnote.bold())
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                        
                        Rectangle() // line de separación
                            .fill(.black.opacity(0.60))
                            .frame(width: 250, height: 1, alignment: .center)
                        
                     // Caja de referencia si es respuesta ........
                        if let replyText = message.replyingToText, let replyNickname = message.replyingToNickname {
                            HStack {
                                Rectangle().fill(.orange)
                                    .frame(width: 3, height: 60)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(replyNickname)")
                                        .font(.caption.bold())
                                    Rectangle()
                                        .fill(.black.opacity(0.60))
                                        .frame(width: 250, height: 1, alignment: .center)
                                        .padding(.vertical, 10)
                                    
                                    Text("\(replyText)")
                                        .font(.caption2)
                                        .lineLimit(2)
                                }
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white.opacity(0.35))
                                    .stroke(Color.black.opacity(0.5), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                     //_________________________//
                        
                        switch message.type{
                            
                        default:
                            Text(message.content)
                                .padding(.horizontal, 10)
                        }
                        
// ................ Reacciones emojis .......................
                        
//__________________________________________________________//
                        HStack {
                            Spacer()
                            Text(privateChatViewModel.formatTime(from: message.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                        }
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(bubbleColor)
                    )
                    .contextMenu{
                        if isCurrentUser {
                            Button(action: {
                                messageText = message.content
                                editingMessageID = message.id
                                isEditing = true
                            }){
                               Label("Editar", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await privateChatViewModel.deleteMessageMark(chatsID: chatID,
                                                                                         messageID: message.id)
                                        let fileURL = try await chatFileViewModel.downloadAndSaveFile(from: message.content)
                                        try FileManager.default.removeItem(at: fileURL)
                                    } catch {
                                        print("Error al eliminar archivo: \(error.localizedDescription)")
                                    }
                                }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }else {
                            Button(action: {
                                replyingToMessageID = message.id
                                replyingToNickname = user?.nickname
                            }, label: {
                                Label("Responder", systemImage: "arrowshape.turn.up.left")
                            })
                        }
                    }
                    
                    TriangleRight()
                        .fill(bubbleColor)
                        .frame(width: 10, height: 10)
                        .offset(x:  -9, y: 10)
                        .scaleEffect( x: isCurrentUser ? 1 : -1, y: 1)
                }
                .frame(maxWidth: 260, alignment: privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? .trailing : .leading)

                .task {
                    await userProfileView.loadUserData()
                    
                }
            }
        }
    }
}

//#Preview {
//    @Previewable @State var mock = Mock()
//    MessageBubbleView(
//        chatID: "previewChat",
//        message: mock.sampleMessage,
//        user: mock.sampleUser,
//        messageText: .constant(""),
//        isEditing: .constant(false),
//        editingMessageID: .constant(nil)
//    )
//    .environment(PrivateChatViewModel())
//}
//

