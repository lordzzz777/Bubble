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
    
    var body: some View {
        NavigationStack{
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack {
                            ForEach(publicChatViewModel.messages, id: \.id) { message in
                                if let user = publicChatViewModel.visibleUsers.first(where: { $0.id == message.senderUserID }) {
                                    PublicMessageBubbleView(
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
                    TextField("Escribe tu mensaje...", text: $messageText, onCommit: {
                        Task{
                            await publicChatViewModel.sendPublicMessage(messageText)
                            messageText = ""
                            textFieldHeight = 40
                        }
                    })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: textFieldHeight)
                        .onChange(of: textFieldHeight) {_,_ in
                            publicChatViewModel.updateHeight(messageText: messageText, textFieldHeight: $textFieldHeight)
                        }
                    
                    Button(action: {
                        if !messageText.isEmpty {
                            Task {
                                await publicChatViewModel.sendPublicMessage(messageText)
                                messageText = ""
                                textFieldHeight = 40
                            }
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                    }
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
}

#Preview {
    PublicChatView()
}
