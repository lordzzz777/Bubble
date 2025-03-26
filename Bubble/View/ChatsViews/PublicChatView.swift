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
    @State private var publicChatViewModel = PublicChatViewModel()
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
                
                HStack {
                    TextField(isEditing ? "Edita tu mensaje..." : "Escribe tu mensaje...", text: $messageText, onCommit:  {
                        Task{
                            await handleSendOrEdit()
//                            await publicChatViewModel.sendPublicMessage(messageText)
//                            messageText = ""
//                            textFieldHeight = 40
                        }
                    })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: textFieldHeight)
                        .onChange(of: textFieldHeight) {_,_ in
                            publicChatViewModel.updateHeight(messageText: messageText, textFieldHeight: $textFieldHeight)
                        }
                    Button(action: {
                        Task {
                            await handleSendOrEdit()
                        }
                    }) {
                        Image(systemName: isEditing ? "pencil.circle.fill" : "paperplane.fill")
                            .foregroundColor(.blue)
                    }
//                    Button(action: {
//                        if !messageText.isEmpty {
//                            Task {
//                                await publicChatViewModel.sendPublicMessage(messageText)
//                                messageText = ""
//                                textFieldHeight = 40
//                            }
//                        }
//                    }) {
//                        Image(systemName: "paperplane.fill")
//                            .foregroundColor(.blue)
//                    }
                }
                .padding()
            }
            .navigationTitle("Chat Café ☕️")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                publicChatViewModel.fetchPublicChatMessages()
                Task {
                    await publicChatViewModel.fetchVisibleUsers()
                }
            }
        }
    }
    
    private func handleSendOrEdit() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let messageID = editingMessageID {
            await publicChatViewModel.editMessage(messageID: messageID, newContent: messageText)
            isEditing = false
            editingMessageID = nil
        } else {
            await publicChatViewModel.sendPublicMessage(messageText)
        }
        messageText = ""
        textFieldHeight = 40
    }
}

#Preview {
    PublicChatView()
}
