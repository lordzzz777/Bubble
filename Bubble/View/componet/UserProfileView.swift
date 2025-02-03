//
//  UserProfileView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 3/2/25.
//

import SwiftUI
import FirebaseCore

struct UserProfileView: View {
    let userID: String
    let timestamp: Timestamp
    @State private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack {
            if let user = viewModel.user {
                HStack {
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
                        HStack{
                            Text(user.nickname)
                                .font(.title2.bold())
                            Spacer()
                            Text(viewModel.formatTimestamp(timestamp))
                                .font(.title3)
                        }
                    }.contextMenu(menuItems: {
                        Button("Actualizar Última Conexión") {
                          viewModel.updateLastConnection(userID: userID)
                        }
                    })
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            viewModel.fetchUser(userID: userID)
        }
    }
}

