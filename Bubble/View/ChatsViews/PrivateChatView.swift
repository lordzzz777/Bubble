//
//  PrivateChatVIew.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import SwiftUI

struct PrivateChatView: View {

    @Environment(PrivateChatViewModel.self) private var chatsViewModel
    @State private var privateChatViewModel = PrivateChatViewModel()
    @State private var messageText: String = ""
    @State private var checkingFriendStatus: Bool = false
    
    var user: UserModel
    var chat: ChatModel

    var body: some View {
        if let user = chatsViewModel.user {
            VStack {
                if user.isDeleted{
                    VStack{
                        Text("Este usuario ha eliminado su cuenta.")
                        Text("El chat ya no está disponible.")
                    }
                    .foregroundStyle(.red)
                    .font(.footnote.bold())
                    .padding()
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack {
                            // Cada grupo de mensajes (por día)
                            ForEach(privateChatViewModel.groupedMessages, id: \.key) { group in
                                // Separador por día
                                HStack(spacing: 8) {
                                    line
                                    Text(privateChatViewModel.dateHeader(for: group.key))
                                    line
                                }
                                .foregroundStyle(Color.secondary)
                                .font(.caption2)
                                .padding(.top, 20)
                                .padding(.horizontal, 10)
                                
                                // Mensajes correspondientes a la fecha
                                ForEach(group.value, id: \.self) { message in
                                    if message.type == .friendRequest {
                                        Text(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message)
                                             ? "Le enviaste una solicitud a \(user.nickname)"
                                             : "\(user.nickname) te envió una solicitud de amistad")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .italic()
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
                            
                            if privateChatViewModel.friendStatus == .none {
                                Text("Tú y \(user.nickname) no son amigos")
                                    .foregroundStyle(.red)
                                    .italic()
                                    .padding(.bottom, 20)
                                    .opacity(checkingFriendStatus ? 0 : 1)
                            }
                        }
                        .onChange(of: privateChatViewModel.lastMessage) { _, lastMessage in
                            withAnimation {
                                proxy.scrollTo(lastMessage, anchor: .bottom)
                            }
                        }
                    }
                }
                
                if privateChatViewModel.friendStatus == .accepted {
                    ZStack(alignment: .bottomTrailing) {
                        TextField("Escribe tu mensaje", text: $messageText)
                            .padding(.trailing, 20)
                            .onSubmit {
                                Task {
                                    if !messageText.isEmpty {
                                        await privateChatViewModel.sendMessage(chatID: chat.id, messageText: messageText)
                                        messageText = ""
                                    }
                                }
                            }
                        
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
            .onAppear {
                Task {
                    checkingFriendStatus = true
                    await privateChatViewModel.checkIfUserIsFriend(userID: user.id)
                    checkingFriendStatus = false
                }
            }
            .task {
                await privateChatViewModel.fetchMessages(chatID: chat.id)
                if privateChatViewModel.showError {
                    print(privateChatViewModel.errorMessage)
                }
            }
        }
    }
    
    // Vista auxiliar para dibujar una línea
    private var line: some View {
           VStack { Divider() }
    }
}


