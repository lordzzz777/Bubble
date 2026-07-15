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
    
    //Instancias de ViewModels
    @FocusState private var isTextFieldFocused: Bool
    @Environment(PublicChatViewModel.self) var publicChatViewModel
    @State private var chatMediaViewModel = ChatMediaViewModel()
    @State private var audioViewModel = ChatAudioViewModel()
    @State private var chatFileViewModel = ChatFileViewModel()
    
    // Paara mostrar y añadir, una imajen del carrete
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var isShowingPhotosPicker = false
    @State private var isShowingCamera = false
    
    @State private var replyingToMessageID: String? = nil
    @State private var replyingToNickname: String? = nil
    @State private var messageText: String = ""
    @State private var textFieldHeight: CGFloat = 40
    @State private var isEditing: Bool = false
    @State private var editingMessageID: String? = nil
    @State private var isShowingFileImporter = false
    @State private var selectedFileURL: URL? = nil
    
    // Variable que guarda el estado del de copia (poerta papeles)
    @State private var showCopiedToast = false
    
    // Para mostrar imagen flotante
    @State private var selectedImageURL: URL? = nil
    @State private var showImageOverlay = false
    
    @State private var isDraggingLeft = false
    @State private var dragOffset: CGSize = .zero
    
    @State private var draft = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack{
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
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
                        .padding(.bottom, 20)
                        .onChange(of: publicChatViewModel.messages) { _,lastMessage in
                            withAnimation {
                                proxy.scrollTo(lastMessage, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // en PublicChatView  ─ indicador
                if let first = publicChatViewModel.typingUsers.first {
                    let nick = publicChatViewModel.userModel(for: first)?.nickname ?? "Alguien"
                    HStack {
                        Text("\(nick) está…").font(.caption)
                        Image(systemName: "ellipsis.message").symbolEffect(.variableColor)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .shimmerPulse()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: publicChatViewModel.typingUsers)
                    .offset(x: 20)
                }

                
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
                        Button { // Camara de foto
                            isShowingCamera = true
                        } label: {
                            Text("Cámara de fotos").bold()
                            Image(systemName: "camera")
                                .font(.system(size: 22))
                                .foregroundStyle(.primary)
                        }
                        
                        Button { // Carrete de foto
                            isShowingPhotosPicker  = true
                        } label: {
                            Text("Carrete de fotos").bold()
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 22))
                                .foregroundStyle(.primary)
                        }
                        
                        Button { // Agregar archivos
                            isShowingFileImporter = true
                        } label: {
                            Text("Agrgar archivos").bold()
                            Image(systemName: "doc")
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
                    .focused($isFocused)
                    .onChange(of: messageText) { _, new in          // ⑤
                        Task { try? await publicChatViewModel.userIsTyping(!new.isEmpty && isFocused) }
                    }
                    .onChange(of: isFocused) { _, focus in
                        Task { try? await publicChatViewModel.userIsTyping(focus && !messageText.isEmpty) }
                    }
                    
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: textFieldHeight)
                    
                    .onChange(of: textFieldHeight) {_,_ in
                        publicChatViewModel.updateHeight(messageText: messageText, textFieldHeight: $textFieldHeight)
                    }
                    
                    if !messageText.isEmpty && isEditing == true{
                        Button {
                            messageText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                        .padding(6)
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
                        Image(systemName: isEditing ? "pencil.circle.fill" : "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .animation(.easeInOut(duration: 0.15), value: messageText)
                    
                    if messageText.isEmpty {
                        buttonTag()// Boton de grabación
                            .animation(.easeInOut(duration: 0.15), value: messageText)
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
                    try? await publicChatViewModel.listenTyping()
                    try? await publicChatViewModel.userIsTyping(false)
                }
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
                    await chatMediaViewModel.sendImageFromPicker(newValue, scope: .public)
                    selectedImageItem = nil
                }
            }
            .onDisappear {
                Task { try? await publicChatViewModel.userIsTyping(false) }
                publicChatViewModel.isPublicChatVisible = false
            }
            .overlay {
                if showImageOverlay, let url = selectedImageURL {
                    
                    // Capa semitransparente
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    // Contenedor que conoce el tamaño de pantalla disponible
                    GeometryReader { geo in
                        ScrollView([.horizontal, .vertical], showsIndicators: false) {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    maxWidth:  geo.size.width,
                                    maxHeight: geo.size.height
                                )
                                .clipped()
                        }
                        // Para centrar cuando la imagen sea más pequeña que la pantalla
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                        
                    }
                    .transition(.scale.combined(with: .opacity))
                    .onTapGesture { withAnimation { showImageOverlay = false } }
                    .contextMenu(menuItems: {
                        // boton de copiar al portapapeles
                        Button(action: {
                            Task{
                                await publicChatViewModel.copyToClopboard(url, $showCopiedToast)
                            }
                        }, label: {
                            Text("Copiar")
                            Image(systemName: "document.on.document")
                                .foregroundColor(.yellow)
                        })
                        
                        Button("Compartir"){
                            // ...
                        }
                    })
                    
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    isShowingCamera = false
                    guard let img = image else { return }           // cancelado
                    
                    Task {
                        try? await chatMediaViewModel.sendCameraImage( // helper en el VM
                            img,
                            scope: .public
                        )
                    }
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
                            await chatFileViewModel.sendFileMessage(selectedURL, scope: .public, replyingTo: replyingToMessageID)
                            replyingToMessageID = nil
                        }
                    }
                case .failure:
                    AppLogger.error("Error al seleccionar archivo.")
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
                    if let localURL = audioViewModel.localAudioURL {
                        let duration = audioViewModel.audioDuration ?? 0
                        try? await chatMediaViewModel.sendPublicVoiceMessage(
                            fileURL: localURL,
                            duration: duration
                        )
                    }
                }
            },
            onCancel: {
                audioViewModel.reset()
            }
        )
    }
}

#Preview {
    PublicChatView()
}
