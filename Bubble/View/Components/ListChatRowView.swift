//
//  UserProfileView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 3/2/25.
//

import SwiftUI
import FirebaseCore

struct ListChatRowView: View {
    
    let chat: ChatModel
    
    @State private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack {
            if let user = viewModel.user {
                HStack(alignment: .center) {
                    ZStack(alignment: .bottomTrailing) {
                        if user.imgUrl.isEmpty {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 45))
                        } else {
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
                            .fill(user.isOnline ? .green : .gray)
                            .frame(width: 15, height: 15)
                    }
                    
                    VStack(alignment: .leading){
                        Text(user.nickname)
                            
                        switch chat.lastMessageType {
                        case .text:
                            Text(chat.lastMessage)
                        case .friendRequest:
                            Text("Quiere ser tu amigo/a")
                                .font(.footnote)
                        case .acceptedFriendRequest:
                            Text("Tú y \(user.nickname) ahora son amigos")
                        case .image:
                            Text("Te ha enviado una imagen")
                        case .video:
                            Text("Te ha enviado un video")
                        }
                    }.contextMenu(menuItems: {
                        Button("Botón onTag") {
                          // ...
                        }
                    })
                    
                    Spacer()
                    
                    if chat.lastMessageType == .friendRequest {
                        Button {
                            
                        } label: {
                            Text("Aceptar")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    
                    Text(viewModel.formatTimestamp(chat.lastMessageTimestamp))
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            viewModel.fetchUser(userID: chat.lastMessageSenderUserID)
        }
    }
}

