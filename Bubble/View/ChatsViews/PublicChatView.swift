//
//  PublicChatView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 11/3/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PublicChatView: View {
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var publicChatViewModel = PublicChatViewModel()
    @State private var replyingToMessageID: String? = nil
    @State private var replyingToNickname: String? = nil
    @State private var messageText: String = ""
    @State private var textFieldHeight: CGFloat = 40
    @State private var isEditing: Bool = false
    @State private var editingMessageID: String? = nil
    
    var body: some View {
        NavigationStack{
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack {
                            ForEach(publicChatViewModel.messages, id: \.id) { message in
                                if let user = publicChatViewModel.visibleUsers.first(where: { $0.id == message.senderUserID }) {
                                    PublicMessageBubbleView(
                                        messageText: $messageText,
                                        isEditing: $isEditing,
                                        editingMessageID: $editingMessageID,
                                        replyingToMessageID: $replyingToMessageID,
                                        replyingToNickname: $replyingToNickname,
                                        message: message,
                                        user: user,
                                        userColor: publicChatViewModel.getColorForUser(userID: message.senderUserID)
                                    )
                                    .frame(maxWidth: .infinity, alignment: message.senderUserID == Auth.auth().currentUser?.uid ? .trailing : .leading)
                                    .padding(message.senderUserID == Auth.auth().currentUser?.uid ? .trailing : .leading, 10)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                        .onChange(of: publicChatViewModel.messages) { _,_ in
                            withAnimation {
                                if let lastMessage = publicChatViewModel.messages.last {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
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
                
                HStack {
                    TextField(isEditing ? "Edita tu mensaje..." : "Escribe tu mensaje...", text: $messageText, onCommit:  {
                        Task{
                      await publicChatViewModel.handleSendOrEdit(
                            messageText: $messageText,
                            editingMessageID: $editingMessageID,
                            textFieldHeight: $textFieldHeight,
                            isEditing: $isEditing,
                            replyingToMessageID: $replyingToMessageID
                            )
                         
                        }
                    })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: textFieldHeight)
                        
                        .onChange(of: textFieldHeight) {_,_ in
                            publicChatViewModel.updateHeight(messageText: messageText, textFieldHeight: $textFieldHeight)
                        }
                    Button(action: {
                        Task {
                          await publicChatViewModel.handleSendOrEdit(
                                messageText: $messageText,
                                editingMessageID: $editingMessageID,
                                textFieldHeight: $textFieldHeight,
                                isEditing: $isEditing,
                                replyingToMessageID: $replyingToMessageID
                            )
                        }
                    }) {
                        Image(systemName: isEditing ? "pencil.circle.fill" : "paperplane.fill")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .focused($isTextFieldFocused)
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
            .navigationTitle("Chat Publico")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                publicChatViewModel.fetchPublicChatMessages()
                Task {
                    await publicChatViewModel.fetchVisibleUsers()
                }
            }
        }
    }
}

#Preview {
    PublicChatView()
}
