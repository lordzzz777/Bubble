//
//  UserProfileView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 3/2/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import Kingfisher

struct ListChatRowView: View {
    
    let chat: ChatModel
    @State private var chatsPrivateViewModel = PrivateChatViewModel()
    @State private var addNewFriendViewModel = AddNewFriendViewModel()
    
    
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    var body: some View {
        VStack {
            
            if let user = chatsPrivateViewModel.user {
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
                            .environment(chatsPrivateViewModel)
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
                                    KFImage(URL(string: user.imgUrl))
                                        .placeholder{
                                            ProgressView()
                                        }
                                        .resizable()
                                        .scaledToFill()
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
//                                switch chat.lastMessageType {
//                                case .text:
//                                    HStack(spacing: 0) {
//                                        if chatsViewModel.checkIfMessageWasSentByCurrentUser(senderUserID: chat.lastMessageSenderUserID) {
//                                            Text("Tú: ")
//                                                .foregroundStyle(.secondary)
//                                        }
//                                        
//                                        Text(chat.lastMessage)
//                                            .font(.footnote)
//                                    }
//                                    .font(.footnote)
//                                case .friendRequest:
//                                    Text("Quiere ser tu amigo/a")
//                                        .font(.footnote)
//                                case .acceptedFriendRequest:
//                                    Text("Tú y \(user.nickname) ahora son amigos")
//                                        .font(.footnote)
//                                case .image:
//                                    Text("Te ha enviado una imagen")
//                                        .font(.footnote)
//                                case .video:
//                                    Text("Te ha enviado un video")
//                                        .font(.footnote)
//                                case .communityInvitation:
//                                    HStack(spacing: 0) {
//                                        if chatsViewModel.checkIfMessageWasSentByCurrentUser(senderUserID: chat.lastMessageSenderUserID) {
//                                            HStack(alignment: .top, spacing: 0) {
//                                                Text("Tú: ")
//                                                    .foregroundStyle(.secondary)
//                                                
//                                                Text("invitaste a una comunidad")
//                                            }
//                                            .font(.footnote)
//                                        } else {
//                                            Text("Te ha invitado a participar de una comunidad")
//                                                .font(.footnote)
//                                        }
//                                    }
//                                case .audio:
//                                    break
//                                    // Nota de voz ...
//                                }
                            }
                        }
                        
                        Spacer()
                        let unreadCount = chatsPrivateViewModel.unreadCount(for: chat)
                        if unreadCount > 0 {
                            Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, unreadCount > 9 ? 6 : 0)
                                .frame(minWidth: 22, minHeight: 22)
                                .background(.red, in: Capsule())
                                .accessibilityLabel("\(unreadCount) pendientes")
                        }
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
                        Text(chatsPrivateViewModel.formatMessageTimestamp(chat.lastMessageTimestamp))
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                            .multilineTextAlignment(.trailing)
                    }
                })
            } else {
                ChatRowSkeleton()
               //ProgressView()
            }
        }
        .onAppear {
            chatsPrivateViewModel.fetchUser(chat: chat)
        }
    }
}
