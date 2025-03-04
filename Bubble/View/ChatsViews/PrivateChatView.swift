//
//  PrivateChatVIew.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import SwiftUI

struct PrivateChatView: View {
    
    @Environment(ChatsViewModel.self) private var chatsViewModel
    @State private var privateChatViewModel = PrivateChatViewModel()
    var user: UserModel
    var chat: ChatModel
    
    var body: some View {
        if let user = chatsViewModel.user {
            VStack {
                ScrollView {
                    LazyVStack {
                        ForEach(privateChatViewModel.messages, id: \.self) { message in
                            if message.type == .acceptedFriendRequest {
                                Text("Tú y \(user.nickname) ahora son amigos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        
                    }
                }
            }
            .navigationTitle(user.nickname)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .task {
                privateChatViewModel.fetchMessages(chatID: chat.id)
                print("messages: \(privateChatViewModel.messages)")
                if privateChatViewModel.showError {
                    print(privateChatViewModel.errorMessage)
                }
            }
        }
    }
}
