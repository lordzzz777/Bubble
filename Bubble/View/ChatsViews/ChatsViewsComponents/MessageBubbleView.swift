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
/// contexto cuando el autor es el usuario autenticado.
struct MessageBubbleView: View {
    @Environment(PrivateChatViewModel.self) private var privateChatViewModel
    
    let chatID: String
    var message: MessageModel
    var user: UserModel?
    
    // Bindings recibidos desde `PrivateChatView`
    @Binding var messageText: String
    @Binding var isEditing: Bool
    @Binding var editingMessageID: String?
    
    private var isCurrentUser: Bool{
        message.senderUserID == Auth.auth().currentUser?.uid
    }
    
    // Colores para el remitente y el receptor
    private var bubbleColor: Color {
        isCurrentUser ? .green.opacity(0.7) : .cyan.opacity(0.7)
    }
    
    @Bindable var userProfileView: NewAccountViewModel = .init()
    // @State private var privateChatViewModel = PrivateChatViewModel()
    
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
// ............... Caja de respuesta .........................
//__________________________________________________________//
                        
                        switch message.type{
                            
                        default:
                            Text(message.content)
                                .padding(.horizontal, 10)
                        }
                        
// ................ Reacciones emojis .......................
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
//                            .overlay(content: {
//                                Image(.bubble)
//                                    .renderingMode(.template)
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(minWidth: 370, maxHeight: 370, alignment: .center)
//                                    .foregroundStyle(bubbleColor)
//                                    .scaleEffect( x: isCurrentUser ? 1 : -1, y: 1)
//                                    .offset(x: isCurrentUser ? -10 : 10, y: -3)
//                            })


//                        RoundedRectangle(cornerRadius: 10)
//                            .fill(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? .green.opacity(0.7) : .cyan.opacity(0.7))
                    )
                    .contextMenu{
                        if isCurrentUser {
                            Button("Editar") {
                                messageText = message.content
                                editingMessageID = message.id
                                isEditing = true
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await privateChatViewModel.deleteMessageMark(chatsID: chatID,
                                                                                         messageID: message.id)
                                    } catch {
                                        /* El ViewModel ya actualiza errorTitle / errorMessage */
                                    }
                                }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
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

#Preview {
    @Previewable @State var mock = Mock()
    MessageBubbleView(
        chatID: "previewChat",
        message: mock.sampleMessage,
        user: mock.sampleUser,
        messageText: .constant(""),
        isEditing: .constant(false),
        editingMessageID: .constant(nil)
    )
    .environment(PrivateChatViewModel())
}


