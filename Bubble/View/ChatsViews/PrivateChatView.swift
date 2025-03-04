//
//  PrivateChatVIew.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import SwiftUI

struct PrivateChatView: View {
    
    @Environment(ChatsViewModel.self) private var chatsViewModel
    @State private var privateChatViewModel = PrivateChatViewModel()
    @State private var messageText: String = ""
    var user: UserModel
    var chat: ChatModel
    
    var body: some View {
        if let user = chatsViewModel.user {
            VStack {
                ScrollView {
                    LazyVStack {
                        ForEach(privateChatViewModel.messages, id: \.self) { message in
                            if message.type == .friendRequest {
                                Text(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? "Le enviaste una solicitud a \(user.nickname)" : "\(user.nickname) te envió una solicitud de amistad")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if message.type == .acceptedFriendRequest {
                                Text("Tú y \(user.nickname) ahora son amigos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if message.type == .text {
                                MessageBubbleView(message: message)
                            }
                        }
                    }
                }
                
                Spacer()
                
                ZStack(alignment: .bottomTrailing) {
                    TextField("Escribe tu mensaje", text: $messageText)
                        .padding(.trailing, 20)
                    
                    if !messageText.isEmpty {
                        Button {
                            messageText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .padding(8)
                .clipShape(
                    RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.gray, lineWidth: 0.3)
                )
                .padding(.bottom, 8)
                .padding(.horizontal, 4)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    
                }
            }
            .navigationTitle(user.nickname)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .task {
                privateChatViewModel.fetchMessages(chatID: chat.id)
                print("messages: \(privateChatViewModel.messages)")
                if privateChatViewModel.showError {
                    print(privateChatViewModel.errorMessage)
                }
            }
        }
    }
}
