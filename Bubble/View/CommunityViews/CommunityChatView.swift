import SwiftUI
import FirebaseCore

struct CommunityChatView: View {
    let community: CommunityModel

    @State private var viewModel = CommunityChatViewModel()
    @State private var messageText = ""
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
                messagesList
                composer
            }
        }
        .navigationTitle(community.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward.circle")
                }
                .accessibilityLabel("Volver")
            }
        }
        .task {
            await viewModel.openCommunity(community)
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .alert(viewModel.errorTitle, isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        CommunityMessageBubbleView(
                            message: message,
                            user: viewModel.member(for: message.senderUserID),
                            userColor: viewModel.colorForUser(userID: message.senderUserID),
                            isCurrentUser: viewModel.isCurrentUser(message.senderUserID)
                        )
                        .id(message.id)
                    }
                }
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
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Mensaje", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

            Button {
                Task {
                    let sent = await viewModel.sendMessage(messageText)
                    if sent {
                        messageText = ""
                        isInputFocused = false
                    }
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.borderedProminent)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.background)
    }
}

private struct CommunityMessageBubbleView: View {
    let message: MessageModel
    let user: UserModel?
    let userColor: Color
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            if isCurrentUser { Spacer(minLength: 48) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(user?.nickname ?? "Usuario")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(userColor)
                        .lineLimit(1)
                }

                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        bubbleColor,
                        in: RoundedRectangle(cornerRadius: 16)
                    )

                Text(message.timestamp.dateValue(), style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            if !isCurrentUser { Spacer(minLength: 48) }
        }
    }

    private var bubbleColor: Color {
        isCurrentUser ? .accentColor : userColor.opacity(0.22)
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
