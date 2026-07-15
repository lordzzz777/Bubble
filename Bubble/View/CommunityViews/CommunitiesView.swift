import SwiftUI
import Kingfisher

struct CommunitiesView: View {
    @State private var viewModel = CommunityChatViewModel()

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
                            CommunityRowView(community: community)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.loadCommunities()
                    }
                }
            }
            .navigationTitle("Comunidades")
            .task {
                await viewModel.loadCommunities()
            }
            .alert(viewModel.errorTitle, isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

private struct CommunityRowView: View {
    let community: CommunityModel

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
        if let url = URL(string: community.imgUrl), !community.imgUrl.isEmpty {
            KFImage(url)
                .placeholder { ProgressView() }
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.secondary.opacity(0.12))
        }
    }
}

#Preview {
    CommunitiesView()
}
