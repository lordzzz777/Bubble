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
    
    //Instancias de ViewModels
    @Environment(PrivateChatViewModel.self) private var chatsViewModel
    @State private var privateChatViewModel = PrivateChatViewModel()
    @State private var audioViewMode = ChatAudioViewModel()
    @State private var chatMediaViewModel = ChatMediaViewModel()
    @State private var chatFileViewModel = ChatFileViewModel()
    @State private var moderationViewModel = ModerationViewModel()
    
    // Paara mostrar y añadir, una imajen del carrete
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var isShowingPhotosPicker = false
    
    // Para mostrar imajen flotante
    @State private var selectedImageURL: URL? = nil
    @State private var showImageOverlay = false
    @State private var isShowingCamera = false
    
    // Variable que guarda el estado del de copia (poerta papeles)
    @State private var showCopiedToast = false

    // Agregar archivo PDF
    @State private var isShowingFileImporter = false
    @State private var selectedFileURL: URL? = nil
    
    // UI State
    @State private var messageText: String = ""
    @State private var checkingFriendStatus: Bool = false
    @State private var isEditing: Bool = false
    @State private var editingMessageID: String? = nil
    @State private var replyingToMessageID: String? = nil
    @State private var replyingToNickname: String? = nil
    @State private var replyingToText: String? = nil
    @State private var textFieldHeight: CGFloat = 40
    
    @State private var draft = ""
    @FocusState private var isFocused: Bool
    
    
    // Datos del contexto
    var user: UserModel
    var chat: ChatModel

    /// La relación puede estar disponible ya en cualquiera de los perfiles aunque
    /// la comprobación asíncrona de Firestore aún no haya terminado.
    private var canSendMessages: Bool {
        guard let currentUID = Auth.auth().currentUser?.uid else { return false }
        return privateChatViewModel.friendStatus == .accepted
            || user.friends.contains(currentUID)
            || privateChatViewModel.me?.friends.contains(user.id) == true
    }
    
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
                                    case .text, .audio, .image, .file:
                                        
                                        let sender = privateChatViewModel.userModel(for: message.senderUserID)
                                        let showAvatar = privateChatViewModel.shouldShowAvatar(currentMessage: message, in: group.value)
                                        PrivateMessageBubbleView(
                                            chatID: chat.id,
                                            message: message,
                                            currentUser: privateChatViewModel.me,
                                            friendUser: user,
                                            senderUser: sender,
                                            showAvatar: showAvatar,
                                            privateOnImageTap: { url in
                                                selectedImageURL = url
                                                withAnimation {
                                                    showImageOverlay = true
                                                }
                                            },
                                            messageText: $messageText,
                                            isEditing: $isEditing,
                                            editingMessageID: $editingMessageID,
                                            replyingToMessageID: $replyingToMessageID,
                                            replyingToNickname: $replyingToNickname,
                                            replyingToText: $replyingToText,
                                            showCopiedToast: $showCopiedToast
                                        )
                                        .transition(
                                            .scale(scale: 0.62, anchor: .center)
                                                .combined(with: .opacity)
                                        )
                                        .frame(maxWidth: .infinity, alignment: message.senderUserID == Auth.auth().currentUser?.uid ? .trailing : .leading)
                                        .padding(message.senderUserID == Auth.auth().currentUser?.uid ? .trailing : .leading, 10)
                                        
                                    default:
                                        EmptyView()
                                        
                                    }
                                }
                            }
                            .animation(
                                .spring(response: 0.38, dampingFraction: 0.62, blendDuration: 0.08),
                                value: privateChatViewModel.messages.map(\.id)
                            )
                            
                            if privateChatViewModel.isFriendStatusLoaded && !canSendMessages {
                                Text("Tú y \(user.nickname) no son amigos")
                                    .foregroundStyle(.red)
                                    .italic()
                                    .padding(.bottom, 20)
                                    .opacity(checkingFriendStatus ? 0 : 1)
                            }
                        }
                        .padding(.bottom, 20)
                        .onChange(of: privateChatViewModel.lastMessage) { _, lastMessage in
                            withAnimation { proxy.scrollTo(lastMessage, anchor: .bottom) }
                        }
                    }
                }
                
                Spacer()
                
                if let first = chatsViewModel.typingUsers.first,
                   let user  = chatsViewModel.userModel(for: first) {
                    HStack{
                        Text("\(user.nickname) está…").font(.caption)

                        Image(systemName: "ellipsis.message").symbolEffect(.variableColor)
                        Spacer()
                    }
                        .foregroundStyle(.secondary)
                        .shimmerPulse()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.25), value: chatsViewModel.typingUsers)
                        .offset(x: 20)
                    
                }
                
                if let nickname = replyingToNickname, let replyText = replyingToText {
                    HStack {
                        Rectangle().fill(.blue).frame(width: 3, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nickname).font(.caption.bold()).foregroundStyle(.blue)
                            Text(replyText).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.22)) {
                                replyingToMessageID = nil
                                replyingToNickname = nil
                                replyingToText = nil
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .frame(height: 50)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Boton de audio
                if audioViewMode.isRecording{
                    VStack(spacing: 6) {
                        
                        // Muestra Honda de sonido al grabar
                        RecordingWaveformView(audioViewModel: audioViewMode)
                            .frame(height: 36)
                            .padding(.horizontal)
                        
                        // Muestra el tiempo de grabacion en acción real
                        Text(audioViewMode.recordingElapsedTime)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.gray)
                    }.padding(.bottom, 4)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                if canSendMessages && moderationViewModel.isBlocked {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.secondary)
                        Text("Has bloqueado a este usuario. Desbloquéalo para enviar mensajes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if canSendMessages {
                    ZStack(alignment: .bottomTrailing) {
                        HStack(spacing: 6){
                            Menu(content:{
                                Button { // LLama a la cámar
                                    isShowingCamera = true
                                } label: {
                                    Text("Cámara de fotos").bold()
                                    Image(systemName: "camera")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.primary)
                                }
                                
                                Button { // LLama a la modal del carrete
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

                            TextField(
                                isEditing ? "Edita tu mensaje..." : "Escribe tu mensaje...",
                                text: $messageText,
                                onCommit: {
                                    awaitSendText()
                                })
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(minHeight: textFieldHeight)
                            .padding(.trailing, 20)
                            .focused($isFocused)
                            .onChange(of: messageText) { _, newVal in
                                Task{
                                   try? await chatsViewModel.userIsTyping(in: chat.id, !newVal.isEmpty && isFocused)
                                }
                            }
                            .onChange(of: isFocused) { _, focus in
                                Task {
                                  try? await chatsViewModel.userIsTyping(in: chat.id, focus && !messageText.isEmpty)
                                }
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
                            
                            Button {
                                awaitSendText()
                            } label: {
                                Image(systemName: isEditing ? "pencil" : "paperplane.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.accentColor, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .animation(.easeInOut(duration: 0.15), value: messageText)
                            
                            
                            
                            if messageText.isEmpty {
                                privateButtonTap()
                                    .animation(.easeInOut(duration: 0.15), value: messageText)
                            }
                            
                        }.padding(.trailing, 4)
                        
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
                    Menu {
                        Button(role: moderationViewModel.isBlocked ? nil : .destructive) {
                            Task {
                                if moderationViewModel.isBlocked {
                                    await moderationViewModel.unblock(userID: user.id)
                                } else {
                                    await moderationViewModel.block(userID: user.id)
                                }
                            }
                        } label: {
                            Label(
                                moderationViewModel.isBlocked ? "Desbloquear usuario" : "Bloquear usuario",
                                systemImage: moderationViewModel.isBlocked ? "hand.raised.slash" : "hand.raised"
                            )
                        }
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
                    await moderationViewModel.loadBlockStatus(userID: user.id)
                    checkingFriendStatus = false
                }
                
                Task{
                    // escucha typing en paralelo
                    try? await chatsViewModel.listenTyping(chatID: chat.id)
                    
                }
                
                Task {
                    // tu bucle de limpieza
                    while true {
                        await privateChatViewModel.cleanUpDeletedMessages(
                            chatID: chat.id,
                            olderThan: 60   // ajusta el tiempo de eliminacion a tu gusto
                        )
                        try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                    }
                }
                
            }
            .onDisappear{
                Task{
                    try await chatsViewModel.userIsTyping(in: chat.id, false)
                }
            }
            .onChange(of: selectedImageItem) { _, newItem in
                Task {
                    await chatMediaViewModel.sendImageFromPicker(
                        newItem,
                        scope: .privateChat(chat.id)
                    )
                    selectedImageItem = nil
                }
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
                                await  privateChatViewModel.privateCopyToClopboard(url, $showCopiedToast)
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
            .task {
                await privateChatViewModel.checkIfUserIsFriend(userID: user.id)
                await privateChatViewModel.fetchMessages(chatID: chat.id)
                if privateChatViewModel.showError {
                    AppLogger.error("Error mostrado por chat privado.")
                }
            }
            
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    isShowingCamera = false
                    guard let img = image else { return }           // cancelado
                    
                    Task {
                        try? await chatMediaViewModel.sendCameraImage( // helper en el VM
                            img,
                            scope: .privateChat(chat.id)
                        )
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false){ result in
                    switch result {
                    case .success(let urls):
                        if let selectedURL = urls.first {
                            selectedFileURL = selectedURL
                            Task{
                                do{
                                    try await chatFileViewModel.validateFileSize(selectedURL)
                                    await chatFileViewModel.sendFileMessage(selectedURL, scope:.privateChat(chat.id), replyingTo: replyingToMessageID)
                                    replyingToMessageID = nil
                                }catch{
                                    AppLogger.error("Error al validar archivo.")
                                }
                            }
                        }
                    case .failure:
                        AppLogger.error("Error al seleccionar archivo.")
                    }
                }
            
            
            .alert(isPresented: $privateChatViewModel.showError) {
                Alert(
                    title: Text(privateChatViewModel.errorTitle),
                    message: Text(privateChatViewModel.errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Error", isPresented: $moderationViewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(moderationViewModel.errorMessage)
            }
            
        }
    }
    
    // Vista auxiliar para dibujar una línea
    private var line: some View {
        VStack { Divider() }
    }
    
    private func awaitSendText(){
        Task{
            await privateChatViewModel.sendText(
                in:               chat.id,
                text:             messageText,
                isEditing:        isEditing,
                editingMessageID: editingMessageID,
                replyingToMessageID: replyingToMessageID,
                replyingToNickname:  replyingToNickname
            )
            
            // Reset de los @State locales (la VM se encarga del resto)
            messageText         = ""
            isEditing           = false
            editingMessageID    = nil
            replyingToMessageID = nil
            replyingToNickname  = nil
            replyingToText      = nil
        }
    }
    
    // metodo parqa el la logica de la grabadora
    @ViewBuilder
    func privateButtonTap() -> some View{
        VoiceRecordingButton(
            onStart: {
                Task{
                    
                    try? await audioViewMode.startRecording()
                    await audioViewMode.startRecordingWaveformUpdates()
                    
                }
            },
            onFinish: {
                Task{
                    
                    await audioViewMode.stopRecording()
                    if let localURL = audioViewMode.localAudioURL {
                        let duration = audioViewMode.audioDuration ?? 0
                        try? await chatMediaViewModel.sendPrivateVoiceMessage(
                            chatID: chat.id,
                            fileURL: localURL,
                            duration: duration
                        )
                    }
                    
                }
            },
            onCancel: {
                audioViewMode.reset()
            })
    }
}
