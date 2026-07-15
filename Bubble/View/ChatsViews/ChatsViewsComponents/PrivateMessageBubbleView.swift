//
//  MessageBubbleView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/4/25.
//

import SwiftUI
import FirebaseAuth
import Kingfisher

struct PrivateMessageBubbleView: View {
    @Environment(PrivateChatViewModel.self) private var privateChatViewModel
    @State private var chatFileViewModel = ChatFileViewModel()
    @State private var chatAudioViewModel = ChatAudioViewModel()
    @State private var chatMediaViewModel = ChatMediaViewModel()
    @State private var bubbleShareViewModel = BubbleShareViewModel()
    @State private var forwardViewModel = ForwardViewModel()
    
    // Estado ventada modal de los emojis
    @State private var isEmojiPickerVisible: Bool = false
    @State private var showSentIcon = false

    
    // Para Ver Archivos PDF
    @State private var previewedFileURL: URL? = nil
    @State private var unsupportedExtension: String? = nil
    @State private var isPreviewPresented = false
    @State private var isDownloading = false
    @State private var decryptedImage: UIImage? = nil
    @State private var showReportSheet = false
    
    // Para renviar mensages
    @State private var isSelecting = false
    
    let chatID: String
    var message: MessageModel
    var currentUser: UserModel?
    var user: UserModel?
    var friendUser: UserModel?
    var senderUser:  UserModel?
    var showAvatar: Bool
    var privateOnImageTap: ((URL) -> Void)? = nil
    
    private var isCurrentUser: Bool {
        message.senderUserID == currentUser?.id
    }
    
    private var displayName: String {
        isCurrentUser
        ? (currentUser?.nickname ?? "Yo")
        : (friendUser?.nickname  ?? "Usuario")
    }
    
    private var avatarURL: URL? {
        URL(string: isCurrentUser
            ? (currentUser?.imgUrl ?? "")
            : (friendUser?.imgUrl  ?? ""))
    }
    
    // Colores para el remitente y el receptor
    private var bubbleColor: Color {
        isCurrentUser ? .green.opacity(0.7) : .cyan.opacity(0.7)
    }
    
    // Bindings recibidos desde `PrivateChatView`
    @Binding var messageText: String
    @Binding var isEditing: Bool
    @Binding var editingMessageID: String?
    @Binding var replyingToMessageID: String?
    @Binding var replyingToNickname: String?
    @Binding var showCopiedToast: Bool
    @Bindable var userProfileView: NewAccountViewModel = .init()
    
    
    var body: some View {
        
        // Condicional para llasmar a las reaccione emojis
        if isEmojiPickerVisible{
            ScrollView(.horizontal, showsIndicators: false){
                HStack(spacing: 8){
                    ForEach(EmojiData.emojiCategories["Reacciones"] ?? [], id: \.self) { emoji in
                        
                        Button(action: {
                            Task{
                                if message.reactions?[Auth.auth().currentUser?.uid ?? ""] == emoji{
                                    await privateChatViewModel.reacToMessageRemove(from: chatID, messageID: message.id)
                                }else{
                                    
                                    await  privateChatViewModel.addReacToMessage(chatsID: chatID,messageID: message.id, emoji: emoji, userID: message.senderUserID)
                                }
                                
                                isEmojiPickerVisible = false
                            }
                        }){
                            Text(emoji).font(.largeTitle)
                        }
                    }
                }.background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.gray.opacity(0.45))
                        .stroke(Color.black.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)
            }
            .transition(.opacity)
        }
        if message.isForwarded == true{
            Text("Reenviado").font(.caption2).italic().foregroundStyle(.orange)
        }
        if message.content == "Mensaje eliminado" {
            HStack {
                Spacer()
                Text("\(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? "Tú" : user?.nickname ?? "Usuario") eliminó este mensaje")
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                Spacer()
            }
        }else {
            HStack(alignment: .bottom, spacing: 10) {
                
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: -10) {
                    VStack(alignment: .leading) {
                        Text(displayName)
                            .font(.footnote.bold())
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                        
                        
                        Rectangle() // line de separación
                            .fill(.black.opacity(0.60))
                            .frame(width: 250, height: 1, alignment: .center)
                        
                        // Caja de referencia si es respuesta ........
                        if let replyText = message.replyingToText, let replyNickname = message.replyingToNickname {
                            HStack {
                                Rectangle().fill(.orange)
                                    .frame(width: 3, height: 60)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(replyNickname)")
                                        .font(.caption.bold())
                                    Rectangle()
                                        .fill(.black.opacity(0.60))
                                        .frame(width: 250, height: 1, alignment: .center)
                                        .padding(.vertical, 10)
                                    
                                    Text("\(replyText)")
                                        .font(.caption2)
                                        .lineLimit(2)
                                }
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white.opacity(0.35))
                                    .stroke(Color.black.opacity(0.5), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        switch message.type{
                        case .audio:
                            AudioMessageView(
                                audioURLString: message.content,
                                duration: message.audioDuration ?? 0,
                                message: message,
                                chatID: chatID,
                                chatAudioViewModel: chatAudioViewModel
                            )
                        case .image:
                            if message.encryptionVersion != nil {
                                if let decryptedImage {
                                    Image(uiImage: decryptedImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 220, maxHeight: 220)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    ProgressView()
                                        .frame(width: 120, height: 120)
                                        .task(id: message.id) {
                                            decryptedImage = try? await chatMediaViewModel.decryptedImage(for: message, chatID: chatID)
                                        }
                                }
                            } else if let url = URL(string: message.content){
                                KFImage(source: .network(url))
                                    .cacheOriginalImage()
                                    .placeholder { ProgressView() }
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 220, maxHeight: 220)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 10)
                                    )
                                    .onTapGesture {
                                        privateOnImageTap?(url)
                                    }
                                
                            }
                            
                        case .file :
                            HStack(spacing: 10){
                                SmartFileThumbnailView(fileURL: URL(string: message.content) ?? URL(fileURLWithPath: "/dev/null"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.attachmentFileName ?? URL(string: message.content)?.lastPathComponent ?? "Archivo")
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Button {
                                        Task {
                                            isDownloading = true
                                            if message.encryptionVersion != nil {
                                                try await chatFileViewModel.previewsEncryptedFile(message, chatID: chatID, isPreviewPresented: $isPreviewPresented, previewedFileURL: $previewedFileURL, unsupportedExtension: $unsupportedExtension)
                                            } else {
                                                try await chatFileViewModel.previewsFile(message.content, isPreviewPresented: $isPreviewPresented, previewedFileURL: $previewedFileURL, unsupportedExtension: $unsupportedExtension)
                                            }
                                            isDownloading = false
                                        }
                                    } label: {
                                        if isDownloading {
                                            ProgressView()
                                        } else {
                                            Label("Abrir archivo", systemImage: "doc.text.viewfinder")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                                .shadow(radius: 10)
                                        }
                                    }
                                    
                                    .sheet(isPresented: $isPreviewPresented) {
                                        if let url = previewedFileURL {
                                            QuickLookPreview(url: url)
                                        } else {
                                            ProgressView("Cargando...")
                                        }
                                    }
                                }
                            }
                            // aqui se le añade los caso oae compartir audio, imagenes...
                        default:
                            Text(message.content)
                                .padding(.horizontal, 10)
                        }
                        
                        // Aqui se pintan las reacciones emojis.
                        if let reactions = message.reactions, !reactions.isEmpty{
                            HStack(spacing: 2){
                                ForEach(Array(Set(reactions.values)), id:\.self){ emoji in
                                    Text(emoji).font(.callout)
                                }
                            }.offset(x: 15, y: 10)
                        }
                        
                        HStack {
                            Spacer()
                            Text(privateChatViewModel.formatTime(from: message.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                        }
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(bubbleColor)
                    )
                    .overlay(
                        Group {
                            if showCopiedToast {
                                Text("Copiado al porta papeles")
                                    .font(.caption.bold())
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .transition(.opacity)
                                    .offset(y: -40)
                            }
                        },
                        alignment: .top
                    )
                    .overlay(alignment: .center) {
                        if showSentIcon {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 100))
                                .foregroundStyle(.orange).shadow(color: .white, radius: 10)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    .onLongPressGesture{
                        withAnimation {
                            forwardViewModel.sourceChatID = chatID
                            forwardViewModel.selecting = true
                            forwardViewModel.toggle(message)
                        }
                    }
                    .onTapGesture {
                        guard isSelecting else { return }
                        withAnimation {
                            forwardViewModel.sourceChatID = chatID
                            forwardViewModel.toggle(message)   // helper que añada/quite
                        }
                    }
                    .contextMenu{
                        // Boton de responder
                        if isCurrentUser {
                            Button(action: {
                                messageText = message.content
                                editingMessageID = message.id
                                isEditing = true
                            }){
                                Label("Editar", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        if message.type == .image || message.type == .audio || message.type == .file {
                                            try await chatFileViewModel.deleteFileFromStorage(message.content)
                                        }
                                        try await privateChatViewModel.deleteMessageMark(chatsID: chatID,
                                                                                         messageID: message.id)
                                    } catch {
                                        AppLogger.error("Error al eliminar mensaje privado.")
                                    }
                                }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }else {
                            Button(action: {
                                replyingToMessageID = message.id
                                replyingToNickname = user?.nickname
                            }, label: {
                                Label("Responder", systemImage: "arrowshape.turn.up.left")
                            })
                            
                            Button(role: .destructive) {
                                showReportSheet = true
                            } label: {
                                Label("Reportar", systemImage: "flag")
                            }
                        }
                        
                        // Boton de reeviar
                        Button(action:{
                            withAnimation {
                                forwardViewModel.sourceChatID = chatID
                                forwardViewModel.selecting = true
                                forwardViewModel.toggle(message)
                            }
                        }, label:{
                            Text("Reenviar")
                            Image(systemName: "arrowshape.turn.up.forward")
                        })
                        
                        // Boton de compartir
                        if let item = bubbleShareViewModel.shareItem(for: message){
                            if let url = item as? URL{
                                let preview = SharePreview(
                                    url.lastPathComponent,
                                    image: bubbleShareViewModel.icon(for: url)
                                )
                                ShareLink(item: url, preview: preview){
                                    Label("Compartir", systemImage: "square.and.arrow.up")
                                }
                                
                            }else if let str = item as? String{
                                ShareLink(item: str) {
                                    Label("Compartir", systemImage: "square.and.arrow.up")
                                }
                            }
                        }else{
                            // Archivo / Audio aún descargando -> boton desactivado
                            if message.type == .file || message.type == .audio {
                                Label("Preparando…", systemImage: "arrow.down").disabled(true)
                            }
                        }
                        
                        // boton de ventana modal emogis
                        Button(action: {
                            isEmojiPickerVisible.toggle()
                        }, label: {
                            Text("Emojis")
                            Image(systemName: "face.smiling")
                                .foregroundColor(.yellow)
                        })
                        
                        // boton de copiar al portapapeles
                        Button(action: {
                            Task{
                                if message.encryptionVersion != nil {
                                    switch message.type {
                                    case .image:
                                        if let decryptedImage {
                                            await privateChatViewModel.privateCopyToClopboard(decryptedImage, $showCopiedToast)
                                        }
                                    case .audio:
                                        if let localURL = try? await chatAudioViewModel.downloadAndCacheEncryptedAudio(message: message, chatID: chatID) {
                                            await privateChatViewModel.privateCopyToClopboard(localURL, $showCopiedToast)
                                        }
                                    case .file:
                                        if let localURL = try? await chatFileViewModel.downloadAndSaveEncryptedFile(message: message, chatID: chatID) {
                                            await privateChatViewModel.privateCopyToClopboard(localURL, $showCopiedToast)
                                        }
                                    default:
                                        await privateChatViewModel.privateCopyToClopboard(message.content, $showCopiedToast)
                                    }
                                } else {
                                    await privateChatViewModel.privateCopyToClopboard(message.content, $showCopiedToast)
                                }
                            }
                        }, label: {
                            Text("Copiar")
                            Image(systemName: "document.on.document")
                                .foregroundColor(.yellow)
                        })
                        
                    }


                    if showAvatar {
                        // pico de la burbuja ..
                        TriangleRight()
                            .fill(bubbleColor)
                            .frame(width: 10, height: 10)
                            .offset(x:  -9, y: 10)
                            .scaleEffect( x: isCurrentUser ? 1 : -1, y: 1)
                        
                        // Avatars ...
                        if let url = avatarURL {
                            KFImage(url)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                                .offset(y: 30)
                            
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 30))
                                .offset(y: 30)
                        }
                    }
                    
                }
                .frame(maxWidth: 260, alignment: privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? .trailing : .leading)
                .sheet(isPresented: $forwardViewModel.selecting) {
                    ForwardSheetView()
                        .environment(privateChatViewModel)
                        .environment(forwardViewModel)
                        .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showReportSheet) {
                    ReportView(
                        reportedUserID: message.senderUserID,
                        messageID: message.id,
                        chatID: chatID,
                        isPublicChat: false
                    )
                }
                .onChange(of: forwardViewModel.selecting) { _, selecting in
                    // Cuando la hoja se cierra (= envío terminado) el flag pasa a false
                    guard !selecting else { return }
                    
                    // evita superposiciones
                    if showSentIcon == false {
                        showSentIcon = true
                        Task {
                            // oculta tras 1 s
                            try? await Task.sleep(for: .seconds(1))
                            showSentIcon = false
                        }
                    }
                }


                .task {
                    await userProfileView.loadUserData()
                    await bubbleShareViewModel.prepare(for: message, chatID: chatID)
                    
                }
            }
            .alert("Error",
                   isPresented: .constant(bubbleShareViewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) { bubbleShareViewModel.errorMessage = nil }
            } message: {
                Text(bubbleShareViewModel.errorMessage ?? "")
            }
            .padding(.bottom, showAvatar ? 20 : 0)

        }
    }
}

#Preview {
    @Previewable @State var msgText           = ""
    @Previewable @State var isEditing         = false
    @Previewable @State var editingID: String? = nil
    @Previewable @State var replyID:   String? = nil
    @Previewable @State var replyName: String? = nil
    @Previewable @State var copied            = false
    let mock = Mock()
    
    return PrivateMessageBubbleView(
        chatID:               "chat_mock",
        message:              mock.samplePDFMessage,
        currentUser:          mock.currentUser,
        user:                 mock.currentUser,
        friendUser:           mock.friendUser,
        senderUser:           mock.friendUser,
        showAvatar:           true,
        messageText:          $msgText,
        isEditing:            $isEditing,
        editingMessageID:     $editingID,
        replyingToMessageID:  $replyID,
        replyingToNickname:   $replyName,
        showCopiedToast:      $copied
    )
    .environment(PrivateChatViewModel())
}

