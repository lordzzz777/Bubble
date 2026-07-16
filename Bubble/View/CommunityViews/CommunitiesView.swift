import SwiftUI
import Kingfisher
import FirebaseAuth
import FirebaseStorage

struct CommunitiesView: View {
    @State private var viewModel = CommunityChatViewModel()
    @State private var createCommunityViewModel = CreateCommunityViewModel()
    @State private var communityToDelete: CommunityModel?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingCommunities && viewModel.communities.isEmpty {
                    ProgressView()
                } else if viewModel.communities.isEmpty {
                    ContentUnavailableView(
                        "No tienes comunidades",
                        systemImage: "person.3.sequence.fill",
                        description: Text("Crea una comunidad o espera una invitación para empezar a chatear.")
                    )
                } else {
                    List(viewModel.communities) { community in
                        NavigationLink {
                            CommunityChatView(community: community)
                        } label: {
                            CommunityRowView(
                                community: community,
                                unreadCount: viewModel.unreadCount(for: community)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if community.ownerUID == Auth.auth().currentUser?.uid {
                                Button(role: .destructive) {
                                    communityToDelete = community
                                } label: {
                                    Label("Eliminar", systemImage: "trash.fill")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.loadCommunities()
                    }
                }
            }
            .navigationTitle("Comunidades")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createCommunityViewModel.showCreateNewCommunity = true
                    } label: {
                        Image(systemName: "person.2.badge.plus.fill")
                    }
                    .accessibilityLabel("Crear comunidad")
                }
            }
            .task {
                await viewModel.loadCommunities()
            }
            .onAppear {
                Task { await viewModel.loadCommunities() }
            }
            .alert(viewModel.errorTitle, isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .confirmationDialog(
                "¿Eliminar \(communityToDelete?.name ?? "esta comunidad")?",
                isPresented: Binding(
                    get: { communityToDelete != nil },
                    set: { if !$0 { communityToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Eliminar comunidad", role: .destructive) {
                    guard let community = communityToDelete else { return }
                    communityToDelete = nil
                    Task { _ = await viewModel.deleteCommunity(community) }
                }
                Button("Cancelar", role: .cancel) { communityToDelete = nil }
            } message: {
                Text("Se eliminarán permanentemente la comunidad y todos sus mensajes.")
            }
            .sheet(isPresented: $createCommunityViewModel.showCreateNewCommunity) {
                CreateCommunityView(createCommunityViewModel: createCommunityViewModel)
            }
            .onChange(of: createCommunityViewModel.showCreateNewCommunity) { _, isPresented in
                guard !isPresented else { return }
                Task {
                    await viewModel.loadCommunities()
                    createCommunityViewModel = CreateCommunityViewModel()
                }
            }
        }
    }
}

private struct CommunityRowView: View {
    let community: CommunityModel
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 12) {
            communityImage
                .frame(width: 52, height: 52)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(community.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(community.lastMessage.isEmpty ? "Sin mensajes todavía" : community.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if unreadCount > 0 {
                Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, unreadCount > 9 ? 6 : 0)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(.red, in: Capsule())
                    .accessibilityLabel("\(unreadCount) mensajes sin leer")
            }

            Text("\(Set(community.members + [community.ownerUID]).count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var communityImage: some View {
        if !community.imgUrl.isEmpty {
            AuthenticatedCommunityImage(storageURL: community.imgUrl)
        } else {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.secondary.opacity(0.12))
        }
    }
}

private struct AuthenticatedCommunityImage: View {
    let storageURL: String
    @State private var image: UIImage?
    @State private var finished = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if !finished {
                ProgressView()
            } else {
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.secondary.opacity(0.12))
        .task(id: storageURL) {
            image = nil
            finished = false
            defer { finished = true }
            let reference = Storage.storage().reference(forURL: storageURL)
            guard let data = try? await reference.data(maxSize: 5 * 1024 * 1024),
                  let loadedImage = UIImage(data: data) else { return }
            image = loadedImage
        }
    }
}

#Preview {
    CommunitiesView()
}
