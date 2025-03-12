//
//  FriendToInviteView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/12/25.
//

import SwiftUI
import FirebaseCore

struct FriendToInviteView: View {
    @State private var createCommunityViewModel: CreateCommunityViewModel = .init()
    var friend: UserModel
    
    var body: some View {
        HStack {
            VStack {
                // Si la url no está vacía se muestra la imagen del usuario. Sino, se muestra una imagen por defecto
                if !friend.imgUrl.isEmpty {
                    AsyncImage(url: URL(string: friend.imgUrl)) { image in
                        image.resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(Circle())
                    .frame(width: 60, height: 60)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                }
            }
            
            Text(friend.nickname)
            
            Spacer()
            
            Button {
                Task {
//                    await addNewFriendViewModel.sendFriendRequest(friendUID: user.id)
                }
            } label: {
                Text("Invitar")
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .clipShape(.capsule)
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    FriendToInviteView(friend: UserModel(id: "1UAaH1mnl6XOQbPJqNz6qnnN8ku1", nickname: "Yeikobu24", imgUrl: "https://firebasestorage.googleapis.com/v0/b/bubble-3080f.firebasestorage.app/o/avatars%2FBepWRX9L8BNGGLfnUmxehfpzB4c2.jpg?alt=media&token=b6079556-f774-4c8d-aed6-c6ddeeb05abc", lastConnectionTimeStamp: Timestamp.init(), isOnline: false, chats: [], friends: []))
}
