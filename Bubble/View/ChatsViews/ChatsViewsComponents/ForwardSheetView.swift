//
//  ForwardSheetView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 12/6/25.
//

import SwiftUI
import Kingfisher

struct ForwardSheetView: View {
    @Environment(ForwardViewModel.self) private var vm: ForwardViewModel?
    @Environment(PrivateChatViewModel.self) private var cache                 
    
    @State private var editMode: EditMode = .active
    
    /// Lista ordenada de amigos
    private var users: [UserModel] {
        cache.usersCache.values.sorted { $0.nickname < $1.nickname }
    }
    
    var body: some View {
        NavigationStack {
            List(users, id: \.id, selection: Binding(
                    get: { vm?.chosenIDs ?? [] },
                    set: { vm?.chosenIDs = $0 }
                )
            ) { user in
                HStack {
                    KFImage(URL(string: user.imgUrl))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    Text(user.nickname)
                }
                .tag(user.id)
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Enviar a…")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reenviar") {
                        Task {
                            await vm?.forward()
                            
                        }
                    }
                    .disabled(vm?.chosenIDs.isEmpty ?? true)
                }
            }
            .overlay {
                if let p = vm?.progress, p > 0, p < 1 {
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                        .padding()
                }
            }
            .task {
                await cache.fetchChats()
            }
        }
    }
}



