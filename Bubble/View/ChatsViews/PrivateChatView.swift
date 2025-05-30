//
//  PrivateChatVIew.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PhotosUI
import Kingfisher

struct PrivateChatView: View {

    @Environment(PrivateChatViewModel.self) private var chatsViewModel
    
    @State private var privateChatViewModel = PrivateChatViewModel()
    @State private var messageText: String = ""
    @State private var checkingFriendStatus: Bool = false
    @State private var isEditing: Bool = false
    @State private var editingMessageID: String? = nil
    @State private var replyingToMessageID: String? = nil
    @State private var replyingToNickname: String? = nil
    @State private var textFieldHeight: CGFloat = 40
    
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
                                HStack(spacing: -8) {
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
                                    switch message.type {
                                    case .friendRequest:
                                        Text(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message)
                                             ? "Le enviaste una solicitud a \(user.nickname)"
                                             : "\(user.nickname) te envió una solicitud de amistad")
                                        .font(.footnote).foregroundStyle(.secondary).italic()
                                    case .acceptedFriendRequest:
                                        Text("Tú y \(user.nickname) ahora son amigos")
                                            .font(.caption).foregroundStyle(.secondary)
                                    case .text:
                                      
                                        let sender = privateChatViewModel.userModel(for: message.senderUserID)
                                        let showAvatar = privateChatViewModel.shouldShowAvatar(currentMessage: message, in: group.value)
                                        PrivateMessageBubbleView(
                                            chatID: chat.id,
                                            message: message,
                                            currentUser: privateChatViewModel.me,
                                            friendUser: user,
                                            senderUser: sender,
                                            showAvatar: showAvatar,
                                            messageText: $messageText,
                                            isEditing: $isEditing,
                                            editingMessageID: $editingMessageID,
                                            replyingToMessageID: $replyingToMessageID,
                                            replyingToNickname: $replyingToNickname
                                        )
                                        .frame(maxWidth: .infinity, alignment: message.senderUserID == Auth.auth().currentUser?.uid ? .trailing : .leading)
                                        .padding(message.senderUserID == Auth.auth().currentUser?.uid ? .trailing : .leading, 10)
                                        
                                    default:
                                        EmptyView()
                                        
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
                        .padding(.bottom, 20)
                        .onChange(of: privateChatViewModel.lastMessage) { _, lastMessage in
                            withAnimation {
                                proxy.scrollTo(lastMessage, anchor: .bottom)
                            }
                        }
                    }
                }
                Spacer()
                
                if let nickname = replyingToNickname {
                    HStack {
                        Text("Respondiendo a \(nickname)")
                            .font(.footnote)
                            .foregroundStyle(.blue)
                        Spacer()
                        Button(action: {
                            replyingToMessageID = nil
                            replyingToNickname = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                }
                
                if privateChatViewModel.friendStatus == .accepted {
                    ZStack(alignment: .bottomTrailing) {
                        TextField(isEditing ? "Edita tu mensaje..." : "Escribe tu mensaje...", text: $messageText, onCommit:  {
                            Task {
                                guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                
                                if isEditing, let id = editingMessageID {
                                    try? await privateChatViewModel.editMessage(
                                        chatsID: chat.id,
                                        messageID: id,
                                        newCountent: messageText
                                    )
                                    isEditing = false
                                    editingMessageID = nil
                                } else {
                                    let originalText = privateChatViewModel.messages.first(where: { $0.id == replyingToMessageID })?.content
                                    await  privateChatViewModel.sendPrivateMessage(
                                        chatID: chat.id,
                                        messageText: messageText,
                                        replyingToMessageID: replyingToMessageID,
                                        replyingToText: originalText,
                                        replyingToNickname: replyingToNickname
                                    )
                                                                        
                                    replyingToMessageID = nil
                                    replyingToNickname = nil
                                }
                                messageText = ""
                            }
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: textFieldHeight)
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
                    
                    while true {
                        await privateChatViewModel.cleanUpDeletedMessages(
                            chatID: chat.id,
                            olderThan: 60   // ajusta el tiempo de eliminacion a tu gusto
                        )
                        try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                    }
                }

            }
            .task {
                await privateChatViewModel.fetchMessages(chatID: chat.id)
                if privateChatViewModel.showError {
                    print(privateChatViewModel.errorMessage)
                }
            }
            .alert(isPresented: $privateChatViewModel.showError) {
                Alert(
                    title: Text(privateChatViewModel.errorTitle),
                    message: Text(privateChatViewModel.errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }

        }
    }
    
    // Vista auxiliar para dibujar una línea
    private var line: some View {
           VStack { Divider() }
    }
}


