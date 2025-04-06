//
//  MatchedFriendRowView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 2/9/25.
//

import SwiftUI
import FirebaseCore
import Kingfisher

struct MatchedFriendRowView: View {
    
    @State private var matchedFriendViewModel: MatchedFriendViewModel = .init()
    @State private var loading: Bool = false
    @State private var isSendingRequest: Bool = false
    
    var user: UserModel
    
    var body: some View {
        HStack {
            VStack {
                // Si la url no está vacía se muestra la imagen del usuario. Sino, se muestra una imagen por defecto
                if !user.imgUrl.isEmpty {
                        KFImage(URL(string: user.imgUrl))
                        .placeholder{
                            ProgressView()
                        }
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .frame(width: 60, height: 60)
                    
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                }
            }
            
            Text(user.nickname)
            
            Spacer()
            
            switch matchedFriendViewModel.friendRequestStatus {
                case .pending:
                    if isSendingRequest {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                isSendingRequest = true
                                await matchedFriendViewModel.cancelFriendRequest(friendUID: user.id)
                                isSendingRequest = false
                            }
                        } label: {
                            Text("Cancelar")
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 50)
                                .fill(Color.secondary)
                        )
                    }
                case .accepted:
                    if isSendingRequest {
                        ProgressView()
                    } else {
                        Button {
                            //
                        } label: {
                            Text("Eliminar")
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 50)
                                .fill(Color.red)
                        )
                    }
                case .none:
                    if isSendingRequest {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                isSendingRequest = true
                                await matchedFriendViewModel.sendFriendRequest(friendUID: user.id)
                                isSendingRequest = false
                            }
                        } label: {
                            Text("Agregar amigo")
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 50)
                                .fill(Color.accentColor)
                        )
                    }
            }
        }
        .redacted(reason: loading ? .placeholder : [])
        .task {
            loading = true
            await matchedFriendViewModel.checkIfFriendRequestPending(friendUID: user.id)
            await matchedFriendViewModel.checkIfFriend(friendUID: user.id)
            loading = false
        }
    }
}

#Preview {
    MatchedFriendRowView(user: UserModel(id: "1UAaH1mnl6XOQbPJqNz6qnnN8ku1", nickname: "Yeikobu24", imgUrl: "https://firebasestorage.googleapis.com/v0/b/bubble-3080f.firebasestorage.app/o/avatars%2FBepWRX9L8BNGGLfnUmxehfpzB4c2.jpg?alt=media&token=b6079556-f774-4c8d-aed6-c6ddeeb05abc", lastConnectionTimeStamp: Timestamp.init(), isOnline: false, chats: [], friends: [], isDeleted: false))
}
