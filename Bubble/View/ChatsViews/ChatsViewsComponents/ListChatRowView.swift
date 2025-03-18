//
//  UserProfileView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 3/2/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

struct ListChatRowView: View {
    
    let chat: ChatModel
    @State private var chatsViewModel = ChatsViewModel()
    @State private var addNewFriendViewModel = AddNewFriendViewModel()
    
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    var body: some View {
        VStack {
            if let user = chatsViewModel.user {
                NavigationLink(destination: {
                    if user.isDeleted {
                        VStack{
                            Text("Este usuario ha eliminado su cuenta.")
                            Text("El chat ya no está disponible.")
                        }
                        .foregroundStyle(.red)
                        .font(.footnote.bold())
                        .padding()
                    } else {
                        PrivateChatView(user: user, chat: chat)
                            .environment(chatsViewModel)
                    }
                }, label: {
                    HStack {
                        ZStack(alignment: .bottomTrailing) {
                            if user.imgUrl.isEmpty {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 45))
                            } else {
                                if user.isDeleted{
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 45))
                                }else{
                                    AsyncImage(url: URL(string: user.imgUrl)) { image in
                                        image.resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .clipShape(Circle())
                                    .frame(width: 45, height: 45)
                                }
                                
                                Circle()
                                    .fill(user.isOnline && !user.isDeleted ? .green : .gray)
                                    .frame(width: 15, height: 15)
                            }
                        }
                        
                        VStack(alignment: .leading){
                            Text(user.nickname)
                                .foregroundColor(user.isDeleted ? .gray : .primary) // Se deshabilita visualmente
                            
                            if user.isDeleted {
                                Text("Usuario eliminado")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            } else {
                                // Aquí para manejar los diferentes tipos de mensajes que pueden venir
                                switch chat.lastMessageType {
                                case .text:
                                    HStack(spacing: 0) {
                                        if chatsViewModel.checkIfMessageWasSentByCurrentUser(senderUserID: chat.lastMessageSenderUserID) {
                                            Text("Tú: ")
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Text(chat.lastMessage)
                                            .font(.footnote)
                                    }
                                    .font(.footnote)
                                case .friendRequest:
                                    Text("Quiere ser tu amigo/a")
                                        .font(.footnote)
                                case .acceptedFriendRequest:
                                    Text("Tú y \(user.nickname) ahora son amigos")
                                        .font(.footnote)
                                case .image:
                                    Text("Te ha enviado una imagen")
                                        .font(.footnote)
                                case .video:
                                    Text("Te ha enviado un video")
                                        .font(.footnote)
                                case .communityInvitation:
                                    HStack(spacing: 0) {
                                        if chatsViewModel.checkIfMessageWasSentByCurrentUser(senderUserID: chat.lastMessageSenderUserID) {
                                            HStack(alignment: .top, spacing: 0) {
                                                Text("Tú: ")
                                                    .foregroundStyle(.secondary)
                                                
                                                Text("invitaste a una comunidad")
                                            }
                                            .font(.footnote)
                                        } else {
                                            Text("Te ha invitado a participar de una comunidad")
                                                .font(.footnote)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        if chat.lastMessageType == .friendRequest {
                            Button {
                                Task {
                                    await addNewFriendViewModel.acceptFriendRequest(chatID: chat.id, senderUID: chat.lastMessageSenderUserID)
                                }
                            } label: {
                                Text("Aceptar")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        Text(chatsViewModel.formatMessageTimestamp(chat.lastMessageTimestamp))
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                            .multilineTextAlignment(.trailing)
                    }
                })
                // .disabled(user.isDeleted) // Deshabilita el chat si el usuario está eliminado
            } else {
                ProgressView()
            }
        }
        .onAppear {
            chatsViewModel.fetchUser(chat: chat)
        }
    }
}
