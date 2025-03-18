//
//  PublicMessageBubbleView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 16/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

struct PublicMessageBubbleView: View {
    var message: MessageModel
    var user: UserModel?
    var userColor: Color
    
    var isCurrentUser: Bool {
        message.senderUserID == Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if !isCurrentUser {
                profileImage()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .offset(x: 5, y: 0)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 30) {
                VStack(alignment:  .leading){
                    Text(user?.nickname ?? "Usuario desconocido")
                        .font(.footnote.bold())
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                    
                    Text(message.content)
                        .padding(.horizontal, 10)
                    HStack {
                        Spacer()
                        Text(formatTimestamp(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                        
                        
                    }
                    
                }.padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                       
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [ userColor.opacity(0.8), userColor.opacity(0.4)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                       
                )
                .foregroundColor(.white)

                if isCurrentUser{
                    TriangleRight().fill(userColor.opacity(0.4))
                        .frame(width: 10, height: 10)
                        .offset(x: -10, y: -30)
                }
                
                if !isCurrentUser {
                    TriangleLeft().fill(userColor)
                        .frame(width: 10, height: 10)
                        .offset(x: 10, y: -30)
                }
                
            } .shadow(radius: 3)
            .frame(maxWidth: 260, alignment: isCurrentUser ? .trailing : .leading)
            
            if isCurrentUser {
                profileImage()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .offset(x: -15, y: 0)
            }
        }

        
    }
    
    @ViewBuilder
    private func profileImage() -> some View {
        if let imageURL = user?.imgUrl, let url = URL(string: imageURL) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.gray)
        }
    }
    
    private func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    PublicMessageBubbleView(
        message: MessageModel(id: "1", senderUserID: "user123", content: "Hola, este es un mensaje público", timestamp: Timestamp(), type: .text),
        user: UserModel(id: "user123", nickname: "Juan Pérez", imgUrl: "", lastConnectionTimeStamp: Timestamp(), isOnline: true, chats: [], friends: [], isDeleted: false),
        userColor: .blue
    )
}
