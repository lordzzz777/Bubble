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
        VStack(alignment: .leading, spacing: 3) {
            if message.content == "Mensaje eliminado" {
                HStack(spacing: 6) {
                    Spacer()
                    Text("\(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? "Tú" : user?.nickname ?? "Usuario") eliminó este mensaje")
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                    Spacer()
                }
            }else {
                HStack(spacing: 6) {
                    
                    VStack(alignment: .leading) {
                        Text(message.content)
                    }
                    Text(privateChatViewModel.formatTime(from: message.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: 6, y: 10)
                    
                }
                .padding()
                .background(
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? .green.opacity(0.7) : .cyan.opacity(0.7))
                    }
                )
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? .trailing : .leading)
        .task {
            await userProfileView.loadUserData()
        }
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


