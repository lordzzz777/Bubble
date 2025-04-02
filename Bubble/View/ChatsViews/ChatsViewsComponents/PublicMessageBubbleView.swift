//
//  PublicMessageBubbleView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 16/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

struct PublicMessageBubbleView: View {
    @State private var publicChatViewModel =  PublicChatViewModel()
    @State private var isEmojiPickerVisible = false
    @State private var showCopiedToast = false
    
    @Binding var messageText: String
    @Binding var isEditing: Bool
    @Binding var editingMessageID: String?
    @Binding var replyingToMessageID: String?
    @Binding var replyingToNickname: String?
    
    var message: MessageModel
    var user: UserModel?
    var userColor: Color
    var showAvatarAndName: Bool
    
    var isCurrentUser: Bool {
        message.senderUserID == Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        if isEmojiPickerVisible {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EmojiData.emojiCategories["Reacciones"] ?? [], id: \.self) { emoji in
                        Button(action: {
                            Task {
                                if message.reactions?[Auth.auth().currentUser?.uid ?? ""] == emoji {
                                    await publicChatViewModel.reacToMessageRemove(from: message.id)
                                } else {
                                    await publicChatViewModel.addReacToMessage(messageID: message.id, emoji: emoji, userID: message.senderUserID)
                                }
                                isEmojiPickerVisible = false
                            }
                        }) {
                            Text(emoji).font(.largeTitle)
                        }
                        
                    }
                }.background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.gray.opacity(0.45))
                        .stroke(Color.black.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)
            }
            .transition(.opacity)
        }
        if message.content == "Mensaje eliminado"{
            HStack {
                Spacer()
                Text("\(user?.nickname ?? "Usuario") eliminó este mensaje")
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                Spacer()
            }
        }else{
            HStack(alignment: .bottom, spacing: 10) {
                if !isCurrentUser && showAvatarAndName {
                    
                    publicChatViewModel.profileImage(user)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .offset(x: 5, y: 0)
                }
                
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: showAvatarAndName ? 30 : -10) {
                    
                   

                    VStack(alignment: .leading) {
                        
                       
                            Text(user?.nickname ?? "Usuario desconocido")
                                .font(.footnote.bold())
                                .foregroundColor(.primary)
                                .padding(.horizontal, 10)
                            
                            Rectangle()
                                .fill(.black.opacity(0.60))
                                .frame(width: 250, height: 1, alignment: .center)
                       
                        
                        // Caja de referencia si es respuesta
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
                        
                        Text(message.content)
                            .padding(.horizontal, 10)
                        if let reactions = message.reactions, !reactions.isEmpty{
                            HStack(spacing: 2){
                                ForEach(Array(Set(reactions.values)), id:\.self){ emoji in
                                    Text(emoji).font(.caption)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.5))
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                }
                            }.offset(x: 15)
                        }
                        HStack {
                            Spacer()
                            Text(publicChatViewModel.formatTimestamp(message.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                        }
                        
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [userColor.opacity(0.8), userColor.opacity(0.4)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                    .foregroundStyle(.primary)
                    .overlay(
                        Group {
                            if showCopiedToast {
                                Text("Copiado al porta papeles")
                                    .font(.caption.bold())
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .transition(.opacity)
                                    .offset(y: -40)
                            }
                        },
                        alignment: .top
                    )
                    .contextMenu {
                        if isCurrentUser {
                            Button(action: {
                                withAnimation(.spring(duration: .zero)) {
                                    messageText = message.content
                                    editingMessageID = message.id
                                    isEditing = true
                                }
                            }) {
                                Label("Editar", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    await publicChatViewModel.deleteMessage(messageID: message.id)
                                }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        } else {
                            
                            Button(action: {
                                replyingToMessageID = message.id
                                replyingToNickname = user?.nickname
                            }, label: {
                                Label("Responder", systemImage: "arrowshape.turn.up.left")
                            })
                            
                        }
                        
                        Button(action: {
                            
                            // logica reenviar a mi lista de contactos ...
                            
                        }, label: {
                            Text("Reenviar")
                            Image(systemName: "arrowshape.turn.up.right")
                        })
                        
                        Button(action: {
                            Task{
                                await publicChatViewModel.copyToClopboard(message.content, $showCopiedToast)
                            }
                        }, label: {
                            Text("Copiar")
                            Image(systemName: "document.on.document")
                        })
                        
                        Button(action: {
                            isEmojiPickerVisible.toggle()
                        }) {
                            Text("Emojis")
                            Image(systemName: "face.smiling")
                                .foregroundColor(.yellow)
                        }
                        

                    }
                    
                    if isCurrentUser && showAvatarAndName {
                        TriangleRight()
                            .fill(userColor.opacity(0.4))
                            .frame(width: 10, height: 10)
                            .offset(x: -10, y: -30)
                    } else if !isCurrentUser && showAvatarAndName {
                        TriangleLeft()
                            .fill(userColor)
                            .frame(width: 10, height: 10)
                            .offset(x: 10, y: -30)
                    }
                }
                .frame(maxWidth: 260, alignment: isCurrentUser ? .trailing : .leading)
                .padding(.horizontal, isCurrentUser && !showAvatarAndName ? 50 : 0)
                .padding(.horizontal, !isCurrentUser && !showAvatarAndName ? 50 : 0)

                if isCurrentUser && showAvatarAndName{
                    publicChatViewModel.profileImage(user)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .offset(x: -15, y: 0)
                }
            }
            
        }
    }
}

//#Preview {
//    PublicMessageBubbleView(
//        messageText: .constant("Hola"),
//        isEditing: .constant(false),
//        editingMessageID: .constant(nil),
//        message: MessageModel(id: "1", senderUserID: "user123", content: "Hola, este es un mensaje público", timestamp: Timestamp(), type: .text),
//        user: UserModel(id: "user123", nickname: "Juan Pérez", imgUrl: "", lastConnectionTimeStamp: Timestamp(), isOnline: true, chats: [], friends: [], isDeleted: false),
//        userColor: .blue
//    )
//}
