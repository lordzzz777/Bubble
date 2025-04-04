//
//  FriendToInviteView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/12/25.
//

import SwiftUI
import FirebaseCore
import Kingfisher

struct FriendToInviteView: View {
    @State private var createCommunityViewModel: CreateCommunityViewModel = .init()
    var friend: UserModel
    @State private var isFriendAdded: Bool = false
    
    var body: some View {
        HStack {
            VStack {
                // Si la url no está vacía se muestra la imagen del usuario. Sino, se muestra una imagen por defecto
                if !friend.imgUrl.isEmpty {
                    KFImage(URL(string: friend.imgUrl))
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
            
            Text(friend.nickname)
            
            Spacer()
            
            Button {
                withAnimation(.bouncy(duration: 0.2)) {
                    isFriendAdded.toggle()
                    
                    if !isFriendAdded {
                        createCommunityViewModel.community.members.append(friend.id)
                    } else {
                        createCommunityViewModel.community.members.removeAll(where: {$0 == friend.id})
                    }
                }
            } label: {
                Text(!isFriendAdded ? "Seleccionar" : "Cancelar")
            }
            .foregroundStyle(!isFriendAdded ? Color.white : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 50)
                    .fill(!isFriendAdded ? Color.accentColor : Color.gray)
            )
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    FriendToInviteView(friend: UserModel(id: "1UAaH1mnl6XOQbPJqNz6qnnN8ku1", nickname: "Yeikobu24", imgUrl: "https://firebasestorage.googleapis.com/v0/b/bubble-3080f.firebasestorage.app/o/avatars%2FBepWRX9L8BNGGLfnUmxehfpzB4c2.jpg?alt=media&token=b6079556-f774-4c8d-aed6-c6ddeeb05abc", lastConnectionTimeStamp: Timestamp.init(), isOnline: false, chats: [], friends: [], isDeleted: false))
}
