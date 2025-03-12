//
//  MessageBubbleView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/4/25.
//

import SwiftUI


struct MessageBubbleView: View {
    
    var message: MessageModel
    var user: UserModel?
    
    @Bindable var userProfileView: NewAccountViewModel = .init()
    @State private var privateChatViewModel = PrivateChatViewModel()
    
    var body: some View {
        VStack {
            
            HStack {
                VStack(alignment: .leading) {
                    HStack{
                        profileImage().padding(6)
                        Text(user?.nickname ?? "").bold()
                    }.padding(.vertical, 5)
                    Text(message.content)
                    
                }
                Text(privateChatViewModel.formatTime(from: message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 6, y: 10)
            }
            .padding()
            .background(
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? .green.opacity(0.7) : .cyan.opacity(0.7))
                }
            )
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? .trailing : .leading)
        .task {
            await userProfileView.loadUserData()
        }
    }
    
    @ViewBuilder
    private func profileImage() -> some View {
        VStack {
            if let imageURL = user?.imgUrl, let url = URL(string: imageURL){
                AsyncImage(url: url){ images in
                    switch images {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 35, height: 35)
                            .clipShape(Circle())
                    case .failure(_):
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 35))
                    @unknown default:
                        EmptyView()
                    }
                }
                
            }else{
                EmptyView()
            }
        }
    }
}

#Preview {
    MessageBubbleView(message: .init(id: "84iKQucP0pOCPOFOp4Db", senderUserID: "1UAaH1mnl6XOQbPJqNz6qnnN8ku1", content: "Hola. Cómo estás?", timestamp: .init(), type: MessageType.text), user: .init(id: "ZvwqAdAu9uhXmmDrXuWXCosfuNC2", nickname:  "Lordzzz", imgUrl: "https://firebasestorage.googleapis.com:443/v0/b/bubble-3080f.firebasestorage.app/o/avatars%2FZvwqAdAu9uhXmmDrXuWXCosfuNC2.jpg?alt=media&token=d7b4a83f-44ce-4d8b-b639-18d275c38162", lastConnectionTimeStamp: .init(), isOnline: true, chats: ["955CD993-F629-4810-AA33-D69CFE4965BB"], friends: ["mDm4pjBWsUM5mIDVw0BRBW5S6RS2"], isDeleted: false))
}
