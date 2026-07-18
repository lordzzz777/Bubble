import SwiftUI
import Kingfisher
import FirebaseAuth
import FirebaseStorage
import PhotosUI

struct CommunitiesView: View {
    @State private var viewModel = CommunityChatViewModel()
    @State private var createCommunityViewModel = CreateCommunityViewModel()
    @State private var communityToDelete: CommunityModel?
    @State private var communityToEdit: CommunityModel?

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
                        .contextMenu {
                            if community.ownerUID == Auth.auth().currentUser?.uid {
                                Button {
                                    communityToEdit = community
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    communityToDelete = community
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if community.ownerUID == Auth.auth().currentUser?.uid {
                                Button {
                                    communityToEdit = community
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
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
            .sheet(item: $communityToEdit) { community in
                EditCommunityView(community: community) { name, image in
                    await viewModel.updateCommunity(community, name: name, image: image)
                }
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

private struct EditCommunityView: View {
    let community: CommunityModel
    let onSave: (String, UIImage?) async -> Bool

    @State private var name: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(community: CommunityModel, onSave: @escaping (String, UIImage?) async -> Bool) {
        self.community = community
        self.onSave = onSave
        _name = State(initialValue: community.name)
    }

    var body: some View {
        let previewImage = selectedImage
        NavigationStack {
            Form {
                Section("Imagen de la comunidad") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Group {
                            if let previewImage {
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .scaledToFill()
                            } else if !community.imgUrl.isEmpty {
                                AuthenticatedCommunityImage(storageURL: community.imgUrl)
                            } else {
                                Image(systemName: "person.3.sequence.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(28)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .frame(maxWidth: .infinity)
                    }
                }

                Section("Nombre") {
                    TextField("Nombre de la comunidad", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Editar comunidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar") {
                            Task {
                                isSaving = true
                                if await onSave(name, selectedImage) { dismiss() }
                                isSaving = false
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                    }
                }
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    selectedImage = image
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
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
