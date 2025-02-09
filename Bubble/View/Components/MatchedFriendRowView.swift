//
//  MatchedFriendRowView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 2/9/25.
//

import SwiftUI
import FirebaseCore

struct MatchedFriendRowView: View {
    
    var user: UserModel
    var sendFriendRequest: () async -> Void
    
    var body: some View {
        HStack {
            VStack {
                if !user.imgUrl.isEmpty {
                    AsyncImage(url: URL(string: user.imgUrl)) { image in
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
            
            Text(user.nickname)
            
            Spacer()
            
            Button {
                Task {
                    await sendFriendRequest()
                }
            } label: {
                Text("Agregar amigo")
                    .padding()
            }
        }
    }
}

#Preview {
    MatchedFriendRowView(user: UserModel(id: "1UAaH1mnl6XOQbPJqNz6qnnN8ku1", nickname: "Yeikobu24", imgUrl: "https://firebasestorage.googleapis.com/v0/b/bubble-3080f.firebasestorage.app/o/avatars%2FBepWRX9L8BNGGLfnUmxehfpzB4c2.jpg?alt=media&token=b6079556-f774-4c8d-aed6-c6ddeeb05abc", lastConnectionTimeStamp: Timestamp.init(), isOnline: false, chats: [], friends: []), sendFriendRequest: {})
}
