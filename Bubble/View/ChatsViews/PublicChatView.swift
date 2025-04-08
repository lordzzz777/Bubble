//
//  PublicChatView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 11/3/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PhotosUI

struct PublicChatView: View {
    @FocusState private var isTextFieldFocused: Bool
    @Environment(PublicChatViewModel.self) var publicChatViewModel
    
    @State private var chatMediaViewModel = ChatMediaViewModel()
    @State private var selectedImageItem: PhotosPickerItem?
   
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
                            LazyVStack {
                                ForEach(publicChatViewModel.messages.indices, id: \.self) { index in
                                    let message = publicChatViewModel.messages[index]
                                    let nextMessage = index + 1 < publicChatViewModel.messages.count ? publicChatViewModel.messages[index + 1] : nil
                                    let showAvatarAndName = nextMessage?.senderUserID != message.senderUserID
                                    
                                    if let user = publicChatViewModel.visibleUsers.first(where: { $0.id == message.senderUserID }) {
                                        PublicMessageBubbleView(
                                            messageText: $messageText,
                                            isEditing: $isEditing,
                                            editingMessageID: $editingMessageID,
                                            replyingToMessageID: $replyingToMessageID,
                                            replyingToNickname: $replyingToNickname,
                                            message: message,
                                            user: user,
                                            userColor: publicChatViewModel.getColorForUser(userID: message.senderUserID),
                                            showAvatarAndName: showAvatarAndName
                                        )
                                        .frame(maxWidth: .infinity, alignment: message.senderUserID == Auth.auth().currentUser?.uid ? .trailing : .leading)
                                        .padding(message.senderUserID == Auth.auth().currentUser?.uid ? .trailing : .leading, 10)
                                    }
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
                
                HStack(spacing: 8) {
                    PhotosPicker(selection: $selectedImageItem, matching: .images, photoLibrary: .shared()){
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                    
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
                publicChatViewModel.isPublicChatVisible = true
                Task {
                    await publicChatViewModel.fetchVisibleUsers()
                    await publicChatViewModel.resetReplyNotificationsIfNeeded()
                    publicChatViewModel.fetchPublicChatMessages()
                    await publicChatViewModel.cleanUpDeletedMessages(olderThan: 300)
                    
                    ///limpieza automática cada minuto
                    while publicChatViewModel.isPublicChatVisible {
                        await publicChatViewModel.cleanUpDeletedMessages(olderThan: 300)
                        try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                    }
                }
            }
            .onChange(of: selectedImageItem){ oldValue, newValue in
                Task{
                    await chatMediaViewModel.sendImageFromPicker(newValue)
                    selectedImageItem = nil
                }
            }
            .onDisappear {
                publicChatViewModel.isPublicChatVisible = false
            }
        }
    }
}

#Preview {
    PublicChatView()
}
