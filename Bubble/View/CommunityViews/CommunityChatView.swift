import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseStorage
import PhotosUI
import UniformTypeIdentifiers
import Kingfisher

struct CommunityChatView: View {
    let community: CommunityModel

    @State private var viewModel = CommunityChatViewModel()
    @State private var messageText = ""
    @State private var showMemberManager = false
    @State private var selectedCommunityImage: PhotosPickerItem?
    @State private var selectedChatImage: PhotosPickerItem?
    @State private var replyingTo: MessageModel?
    @State private var editingMessage: MessageModel?
    @State private var editedText = ""
    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var audioViewModel = ChatAudioViewModel()
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingMessages {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.hasAccess {
                ContentUnavailableView(
                    "Sin acceso",
                    systemImage: "lock.fill",
                    description: Text("No tienes acceso a este chat.")
                )
            } else {
                communityImageHeader
                messagesList
                composer
            }
        }
        .navigationTitle(community.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if community.ownerUID == Auth.auth().currentUser?.uid {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMemberManager = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Invitar miembros")
                }
            }
        }
        .task {
            await viewModel.openCommunity(community)
            while !Task.isCancelled {
                await viewModel.cleanUpDeletedMessages(olderThan: 60)
                try? await Task.sleep(for: .seconds(10))
            }
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .alert(viewModel.errorTitle, isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $showMemberManager) {
            CommunityMemberManagerView(community: community, viewModel: viewModel)
        }
    }

    private var communityImageHeader: some View {
        let imageURL = viewModel.communityImageURL
        let isUpdating = viewModel.isUpdatingCommunityImage
        return Group {
            if community.ownerUID == Auth.auth().currentUser?.uid {
                PhotosPicker(selection: $selectedCommunityImage, matching: .images) {
                    CommunityImageBadge(storageURL: imageURL, isUpdating: isUpdating)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                }
                .onChange(of: selectedCommunityImage) { _, item in
                    Task {
                        guard let data = try? await item?.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else { return }
                        await viewModel.updateCommunityImage(image, communityID: community.id)
                    }
                }
            } else {
                CommunityImageBadge(storageURL: imageURL, isUpdating: isUpdating)
            }
        }
        .padding(.top, 8)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        let nextMessage = index + 1 < viewModel.messages.count ? viewModel.messages[index + 1] : nil

                        if shouldShowDateSeparator(at: index) {
                            CommunityDateSeparator(date: message.timestamp.dateValue())
                        }

                        CommunityMessageBubbleView(
                            communityID: community.id,
                            message: message,
                            user: viewModel.member(for: message.senderUserID),
                            userColor: viewModel.colorForUser(userID: message.senderUserID),
                            isCurrentUser: viewModel.isCurrentUser(message.senderUserID),
                            canModerate: community.ownerUID == Auth.auth().currentUser?.uid,
                            showAvatar: nextMessage?.senderUserID != message.senderUserID,
                            loadAttachment: { await viewModel.attachmentData(for: message) },
                            onReply: {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    replyingTo = message
                                }
                                isInputFocused = true
                            },
                            onReact: { emoji in Task { await viewModel.react(to: message, emoji: emoji) } },
                            onEdit: {
                                editingMessage = message
                                editedText = message.content
                            },
                            onDelete: {
                                Task {
                                    try? await viewModel.deleteMessageMark(messageID: message.id)
                                }
                            }
                        )
                        .transition(
                            .scale(scale: 0.62, anchor: .center)
                                .combined(with: .opacity)
                        )
                        .id(message.id)
                    }
                }
                .animation(
                    .spring(response: 0.38, dampingFraction: 0.62, blendDuration: 0.08),
                    value: viewModel.messages.map(\.id)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.messages) { _, messages in
                guard let lastID = messages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if audioViewModel.isRecording {
                VStack(spacing: 6) {
                    RecordingWaveformView(audioViewModel: audioViewModel)
                        .frame(height: 36).padding(.horizontal)
                    Text(audioViewModel.recordingElapsedTime)
                        .font(.caption.monospacedDigit()).foregroundStyle(.gray)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if let replyingTo {
                HStack {
                    Rectangle().fill(.blue).frame(width: 3, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.member(for: replyingTo.senderUserID)?.nickname ?? "Usuario")
                            .font(.caption.bold()).foregroundStyle(.blue)
                        Text(replyingTo.content).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.22)) {
                            self.replyingTo = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .frame(height: 50)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(alignment: .bottom, spacing: 10) {
                Menu {
                    Button { showCamera = true } label: {
                        Label("Cámara de fotos", systemImage: "camera")
                    }
                    Button { showPhotoLibrary = true } label: {
                        Label("Carrete de fotos", systemImage: "photo.on.rectangle")
                    }
                    Button { showFileImporter = true } label: {
                        Label("Archivo", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "paperclip").font(.system(size: 22, weight: .bold))
                }

            TextField("Mensaje", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .submitLabel(.send)
                .onSubmit {
                    sendTextMessage()
                }
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

            Button {
                sendTextMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor, in: Circle())
            }
            .buttonStyle(.plain)
            .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .animation(.easeInOut(duration: 0.15), value: messageText)

                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                                if let url = audioViewModel.localAudioURL {
                                    _ = await viewModel.sendVoice(
                                        fileURL: url,
                                        duration: audioViewModel.audioDuration ?? 0
                                    )
                                }
                                audioViewModel.reset()
                            }
                        },
                        onCancel: { audioViewModel.reset() }
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.background)
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedChatImage,
            matching: .images
        )
        .onChange(of: selectedChatImage) { _, item in
            Task {
                guard let item else { return }
                defer { selectedChatImage = nil }

                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    _ = await viewModel.sendImage(image)
                } catch {
                    viewModel.showError(
                        title: "No se pudo abrir la foto",
                        message: "No se pudo cargar la imagen seleccionada. Comprueba que esté descargada de iCloud e inténtalo de nuevo."
                    )
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data, .content], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { _ = await viewModel.sendFile(url) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                guard let image else { return }
                Task { _ = await viewModel.sendImage(image) }
            }
        }
        .alert("Editar mensaje", isPresented: Binding(
            get: { editingMessage != nil },
            set: { if !$0 { editingMessage = nil } }
        )) {
            TextField("Mensaje", text: $editedText)
            Button("Cancelar", role: .cancel) { editingMessage = nil }
            Button("Guardar") {
                guard let message = editingMessage else { return }
                Task {
                    if await viewModel.edit(message, content: editedText) { editingMessage = nil }
                }
            }
        }
    }

    private func sendTextMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task {
            let sent = await viewModel.sendMessage(messageText, replyingTo: replyingTo)
            if sent {
                messageText = ""
                withAnimation(.easeOut(duration: 0.22)) {
                    replyingTo = nil
                }
                isInputFocused = false
            }
        }
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard viewModel.messages.indices.contains(index) else { return false }
        guard index > 0 else { return true }

        let calendar = Calendar.autoupdatingCurrent
        let currentDate = viewModel.messages[index].timestamp.dateValue()
        let previousDate = viewModel.messages[index - 1].timestamp.dateValue()
        return !calendar.isDate(currentDate, inSameDayAs: previousDate)
    }
}

private struct CommunityDateSeparator: View {
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Divider()
            Text(title)
                .fixedSize()
            Divider()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInYesterday(date) { return "Ayer" }

        return date.formatted(
            Date.FormatStyle()
                .day(.twoDigits)
                .month(.twoDigits)
                .year()
                .locale(Locale(identifier: "es_ES"))
        )
    }
}

private struct CommunityImageBadge: View, Sendable {
    let storageURL: String
    let isUpdating: Bool

    var body: some View {
        CommunityHeaderImage(storageURL: storageURL)
            .frame(width: 76, height: 76)
            .clipShape(Circle())
            .overlay {
                if isUpdating { ProgressView() }
            }
    }
}

private struct CommunityHeaderImage: View {
    let storageURL: String

    var body: some View {
        if let url = URL(string: storageURL), !storageURL.isEmpty {
            KFImage(url)
                .placeholder {
                    placeholder
                }
                .fade(duration: 0.2)
                .cancelOnDisappear(true)
                .resizable()
                .scaledToFill()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.3.sequence.fill")
            .font(.system(size: 34))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.secondary.opacity(0.12))
    }
}

private struct CommunityMemberManagerView: View {
    let community: CommunityModel
    @Bindable var viewModel: CommunityChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRoles: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingInvitableFriends {
                    ProgressView()
                } else if viewModel.invitableFriends.isEmpty {
                    ContentUnavailableView("No hay amigos disponibles", systemImage: "person.2.slash")
                } else {
                    List(viewModel.invitableFriends) { friend in
                        HStack {
                            Text(friend.nickname)
                            Spacer()
                            Picker("Rol", selection: Binding(
                                get: { selectedRoles[friend.id] ?? "member" },
                                set: { selectedRoles[friend.id] = $0 }
                            )) {
                                Text("Miembro").tag("member")
                                Text("Moderador").tag("moderator")
                                Text("Administrador").tag("admin")
                            }
                            .labelsHidden()
                            Button("Añadir") {
                                Task {
                                    let value = selectedRoles[friend.id] ?? "member"
                                    let role: AdminRole? = value == "admin" ? .admin : (value == "moderator" ? .moderator : nil)
                                    _ = await viewModel.addMember(friend, role: role, to: community)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("Invitar miembros")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task { await viewModel.loadInvitableFriends(for: community) }
        }
    }
}

private struct CommunityMessageBubbleView: View {
    @State private var shareViewModel = BubbleShareViewModel()
    @State private var forwardViewModel = ForwardViewModel()
    @State private var privateChatCache = PrivateChatViewModel()
    @State private var showReportSheet = false
    @State private var showCopiedConfirmation = false
    @State private var showReactionPicker = false
    let communityID: String
    let message: MessageModel
    let user: UserModel?
    let userColor: Color
    let isCurrentUser: Bool
    let canModerate: Bool
    let showAvatar: Bool
    let loadAttachment: () async -> Data?
    let onReply: () -> Void
    let onReact: (String?) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
        if message.content == "Mensaje eliminado" {
            HStack {
                Spacer()
                Text("\(isCurrentUser ? "Tú" : (user?.nickname ?? "Usuario")) eliminó este mensaje")
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                Spacer()
            }
            .transition(.opacity)
        } else {
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
            if showReactionPicker {
                MessageReactionPicker(
                    selectedEmoji: message.reactions?[Auth.auth().currentUser?.uid ?? ""],
                    onSelect: { emoji in
                        let current = message.reactions?[Auth.auth().currentUser?.uid ?? ""]
                        onReact(current == emoji ? nil : emoji)
                        showReactionPicker = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

        HStack(alignment: .bottom) {
            if isCurrentUser { Spacer(minLength: 48) }

            if showAvatar {
                if !isCurrentUser {
                    CommunityUserAvatar(user: user)
                        .frame(width: 40, height: 40)
                }
            } else if !isCurrentUser {
                Color.clear.frame(width: 40, height: 1)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: -10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isCurrentUser ? "Yo" : (user?.nickname ?? "Usuario desconocido"))
                        .font(.footnote.bold())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)

                    Rectangle().fill(.black.opacity(0.60)).frame(width: 250, height: 1)

                if let nickname = message.replyingToNickname, let text = message.replyingToText {
                    HStack {
                        Rectangle().fill(.blue).frame(width: 3, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nickname).font(.caption.bold())
                            Text(text).font(.caption2).lineLimit(1)
                        }
                    }
                    .padding(4)
                    .frame(height: 50)
                    .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                }

                CommunityMessageContent(
                    communityID: communityID,
                    message: message,
                    isCurrentUser: isCurrentUser,
                    loadAttachment: loadAttachment
                )
                    .padding(.horizontal, 10)

                if let reactions = message.reactions, !reactions.isEmpty {
                    MessageReactionSummary(reactions: reactions)
                }

                Text(message.timestamp.dateValue(), style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
                .padding(3)
                .padding(.leading, isCurrentUser ? 0 : 8)
                .padding(.trailing, isCurrentUser ? 8 : 0)
                .background {
                    CommunityChatBubbleBackground(
                        color: bubbleColor,
                        isCurrentUser: isCurrentUser,
                        showsTail: showAvatar
                    )
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button(action: onReply) { Label("Responder", systemImage: "arrowshape.turn.up.left") }

                    if let item = shareViewModel.shareItem(for: message) {
                        if let url = item as? URL {
                            ShareLink(item: url) { Label("Compartir", systemImage: "square.and.arrow.up") }
                        } else if let text = item as? String {
                            ShareLink(item: text) { Label("Compartir", systemImage: "square.and.arrow.up") }
                        }
                    } else if shareViewModel.isWorking {
                        Label("Preparando…", systemImage: "arrow.down.circle").disabled(true)
                    }

                    Button {
                        forwardViewModel.sourceChatID = communityID
                        forwardViewModel.toggle(message)
                        forwardViewModel.selecting = true
                    } label: {
                        Label("Reenviar", systemImage: "arrowshape.turn.up.forward")
                    }

                    if message.type == .text && message.content != "Mensaje eliminado" {
                        Button {
                            UIPasteboard.general.string = message.content
                            showCopiedConfirmation = true
                        } label: {
                            Label("Copiar", systemImage: "doc.on.doc")
                        }
                    }
                    Button {
                        withAnimation { showReactionPicker.toggle() }
                    } label: {
                        Label("Emojis", systemImage: "face.smiling")
                    }
                    if isCurrentUser && message.type == .text && message.content != "Mensaje eliminado" {
                        Button(action: onEdit) { Label("Editar", systemImage: "pencil") }
                    }
                    if (isCurrentUser || canModerate) && message.content != "Mensaje eliminado" {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                    if !isCurrentUser {
                        Button(role: .destructive) { showReportSheet = true } label: {
                            Label("Reportar", systemImage: "flag")
                        }
                    }
                }
                .overlay(alignment: .top) {
                    if showCopiedConfirmation {
                        Text("Copiado al portapapeles")
                            .font(.caption.bold())
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .offset(y: -38)
                            .task {
                                try? await Task.sleep(for: .seconds(1.2))
                                showCopiedConfirmation = false
                            }
                    }
                }
            }

            if showAvatar {
                if isCurrentUser {
                    CommunityUserAvatar(user: user)
                        .frame(width: 40, height: 40)
                }
            } else if isCurrentUser {
                Color.clear.frame(width: 40, height: 1)
            }

            if !isCurrentUser { Spacer(minLength: 48) }
        }
            }
        }
        }
        .frame(maxWidth: 300, alignment: isCurrentUser ? .trailing : .leading)
        .sheet(isPresented: $forwardViewModel.selecting) {
            ForwardSheetView()
                .environment(privateChatCache)
                .environment(forwardViewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showReportSheet) {
            ReportView(
                reportedUserID: message.senderUserID,
                messageID: message.id,
                chatID: communityID,
                isPublicChat: false
            )
        }
        .task(id: message.id) {
            await shareViewModel.prepare(for: message, chatID: communityID)
        }
        .onDisappear {
            shareViewModel.cleanupTemporaryShareFile()
        }
    }

    private var bubbleColor: Color {
        isCurrentUser ? .green.opacity(0.7) : .cyan.opacity(0.7)
    }
}

/// Dibuja cuerpo y pico por separado para que la cola izquierda no genere
/// huecos ni artefactos de relleno al solaparse con el globo.
private struct CommunityChatBubbleBackground: View {
    let color: Color
    let isCurrentUser: Bool
    let showsTail: Bool

    var body: some View {
        GeometryReader { geometry in
            let tailWidth: CGFloat = 10
            let reservedTailWidth = showsTail ? tailWidth : 0
            let bodyX = isCurrentUser ? 0 : reservedTailWidth
            let bodyWidth = max(0, geometry.size.width - reservedTailWidth)

            RoundedRectangle(cornerRadius: 10)
                .fill(color)
                .frame(width: bodyWidth, height: geometry.size.height)
                .offset(x: bodyX)

            if showsTail {
                CommunityChatBubbleTail(isCurrentUser: isCurrentUser)
                    .fill(color)
                    .frame(width: 13, height: 18)
                    .position(
                        x: isCurrentUser ? geometry.size.width - 6.5 : 6.5,
                        y: geometry.size.height - 12
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CommunityChatBubbleTail: Shape {
    let isCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isCurrentUser {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.minX + 2, y: rect.maxY - 5)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 4))
        } else {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.maxX - 2, y: rect.maxY - 5)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
        }
        path.closeSubpath()
        return path
    }
}

private struct CommunityUserAvatar: View {
    let user: UserModel?

    var body: some View {
        KFImage(URL(string: user?.imgUrl ?? ""))
            .placeholder {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().foregroundStyle(.secondary)
            }
            .resizable().scaledToFill().clipShape(Circle())
    }
}

private struct CommunityMessageContent: View {
    let communityID: String
    let message: MessageModel
    let isCurrentUser: Bool
    let loadAttachment: () async -> Data?
    @State private var image: UIImage?
    @State private var chatAudioViewModel = ChatAudioViewModel()

    var body: some View {
        Group {
            switch message.type {
            case .image:
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 220, height: 180).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                } else {
                    ProgressView().frame(width: 220, height: 150)
                }
            case .file:
                Label(message.attachmentFileName ?? "Archivo adjunto", systemImage: "doc.fill")
                    .foregroundStyle(isCurrentUser ? .white : .primary)
            case .audio:
                AudioMessageView(
                    audioURLString: message.content,
                    duration: message.audioDuration ?? 0,
                    message: message,
                    chatID: communityID,
                    chatAudioViewModel: chatAudioViewModel
                )
            default:
                Text(message.content).font(.body)
                    .foregroundStyle(isCurrentUser ? .white : .primary)
            }
        }
        .task(id: message.id) {
            guard message.type == .image, let data = await loadAttachment() else { return }
            image = UIImage(data: data)
        }
    }
}

#Preview {
    NavigationStack {
        CommunityChatView(
            community: CommunityModel(
                name: "Comunidad",
                imgUrl: "",
                createdAt: Timestamp(date: .now),
                ownerUID: "owner",
                lastMessage: "",
                messages: [],
                admins: [],
                members: ["owner"],
                blockedUsers: [],
                admissionRequests: []
            )
        )
    }
}
