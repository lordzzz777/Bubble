//
//  UserProfileView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 3/2/25.
//

import SwiftUI
import FirebaseCore

struct ListChatRowView: View {
    
    let userID: String
    let lastMessage: String
    let timestamp: Timestamp
    
    @State private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack {
            if let user = viewModel.user {
                HStack(alignment: .center) {
                    AsyncImage(url: URL(string: user.imgUrl)) { image in
                        image.resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(Circle())
                    .overlay(content: {
                        Circle()
                            .fill(user.isOnline ? .green : .gray)
                            .frame(width: 20, height: 20)
                            .offset(x: 23, y: 23)
                    })
                    .frame(width: 60, height: 60)
                    
                    VStack(alignment: .leading){
                        Text(user.nickname)
                            .font(.title2)
                        Text(lastMessage).font(.footnote)

                    }.contextMenu(menuItems: {
                        Button("Actualizar Última Conexión") {
                            Task {
                              // viewModel.updateLastConnection(userID: userID)
                                
                            }
                        }
                    })
                    Spacer()
                    Text(viewModel.formatTimestamp(timestamp))
                        .font(.title3).foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            Task{
                await viewModel.fetchUser(userID: userID)
            }
        }
    }
}

