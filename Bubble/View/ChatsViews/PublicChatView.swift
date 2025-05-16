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
import Kingfisher

struct PublicChatView: View {
    @FocusState private var isTextFieldFocused: Bool
    @Environment(PublicChatViewModel.self) var publicChatViewModel
    
    
    @State private var chatMediaViewModel = ChatMediaViewModel()
    @State private var audioViewModel = ChatAudioViewModel()
    @State private var chatFileViewModel = ChatFileViewModel()
    
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var isShowingPhotosPicker = false
    
    @State private var replyingToMessageID: String? = nil
    @State private var replyingToNickname: String? = nil
    @State private var messageText: String = ""
    @State private var textFieldHeight: CGFloat = 40
    @State private var isEditing: Bool = false
    @State private var editingMessageID: String? = nil
    @State private var isShowingFileImporter = false
    @State private var selectedFileURL: URL? = nil
    
    // Para mostrar imagen flotante
    @State private var selectedImageURL: URL? = nil
    @State private var showImageOverlay = false
    
    @State private var isDraggingLeft = false
    @State private var dragOffset: CGSize = .zero
    
    
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
                                            showAvatarAndName: showAvatarAndName,
                                            onImageTap: { url in
                                                selectedImageURL = url
                                                withAnimation {
                                                    showImageOverlay = true
                                                }
                                            }
                                            
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
                
                // Justo antes del HStack de entrada (el que contiene el TextField, botones, etc.)
                if audioViewModel.isRecording {
                    VStack(spacing: 6) {
                        
                        // Muestra Honda de sonido al grabar
                        RecordingWaveformView(audioViewModel: audioViewModel)
                            .frame(height: 36)
                            .padding(.horizontal)
                        
                        // Muestra el tiempo de grabacion en acción real
                        Text(audioViewModel.recordingElapsedTime)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.gray)
                        
                    }
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                HStack(spacing: 8) {
                    Menu(content: {
                        
                        Button { // Agregar archivos
                            isShowingFileImporter = true
                        } label: {
                            Text("Agrgar archivos").bold()
                            Image(systemName: "doc")
                                .font(.system(size: 22))
                                .foregroundStyle(.primary)
                        }
                        
                        Button { // Agregar archivos
                            isShowingPhotosPicker  = true
                        } label: {
                            Text("Carrete de fotos").bold()
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 22))
                                .foregroundStyle(.primary)
                        }
                        
                        Button { // Agregar archivos
                            // ...
                        } label: {
                            Text("Cámara de fotos").bold()
                            Image(systemName: "camera")
                                .font(.system(size: 22))
                                .foregroundStyle(.primary)
                        }
                        
                    }, label: {
                        Image(systemName: "paperclip").font(.system(size: 22).bold())
                            .foregroundStyle(.primary)
                    })
                    
                    // Agregar imagen de carrete
                    .photosPicker(
                        isPresented: $isShowingPhotosPicker,
                        selection: $selectedImageItem,
                        matching: .images
                    )
                    
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
                    
                    if !messageText.isEmpty{
                        
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
                            withAnimation(.linear){
                                Image(systemName: isEditing ?  "paperplane.fill" : "arrow.up.circle.fill")
                                    .font(.system(size: 22).bold())
                            }
                        }
                        
                    }
                    
                    buttonTag()// Boton de grabación
                    
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
            .overlay{
                if showImageOverlay, let url = selectedImageURL{
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    showImageOverlay = false
                                }
                            }
                        
                        KFImage(url)
                            .resizable()
                            .scaledToFit()
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 10)
                            .onTapGesture {
                                withAnimation {
                                    showImageOverlay = false
                                }
                            }
                    }
                    .transition(.scale.combined(with: .opacity))
                    
                }
            }
            
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let selectedURL = urls.first {
                        selectedFileURL = selectedURL
                        Task {
                            try? await chatFileViewModel.validateFileSize(selectedURL)
                            await chatFileViewModel.sendFileMessage(selectedURL, replyingTo: replyingToMessageID)
                            replyingToMessageID = nil
                        }
                    }
                case .failure(let error):
                    print("Error al seleccionar archivo: \(error.localizedDescription)")
                }
            }

            
            .onDisappear {
                publicChatViewModel.isPublicChatVisible = false
            }
        }
    }
    
    @ViewBuilder
    func buttonTag() -> some View {
        VoiceRecordingButton(
            onStart: {
                Task {
                    try? await audioViewModel.startRecording()
                    await audioViewModel.startRecordingWaveformUpdates()
                }
            },
            onFinish: {
                Task {
                    await audioViewModel.stopRecording()
                    try? await audioViewModel.uploadVoiceNote()
                    if let url = audioViewModel.uploadedAudioURL{
                        let duration = audioViewModel.audioDuration ?? 0
                        try? await chatMediaViewModel.sendVoiceMessage(with: url, duration: duration)
                    }
                }
            },
            onCancel: {
                audioViewModel.reset()
            },
            
        )
        
    }
}

#Preview {
    PublicChatView()
}
