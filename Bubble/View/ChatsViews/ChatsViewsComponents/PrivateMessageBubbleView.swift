//
//  MessageBubbleView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/4/25.
//

import SwiftUI
import FirebaseAuth
import Kingfisher

struct PrivateMessageBubbleView: View {
    @Environment(PrivateChatViewModel.self) private var privateChatViewModel
    @State private var chatFileViewModel = ChatFileViewModel()
    @State private var chatAudioViewModel = ChatAudioViewModel()
    
    // Estado ventada modal de los emojis
    @State private var isEmojiPickerVisible: Bool = false
    
    let chatID: String
    var message: MessageModel
    var currentUser: UserModel?
    var user: UserModel?
    var friendUser: UserModel?
    var senderUser:  UserModel?
    var showAvatar: Bool
    
    private var isCurrentUser: Bool {
        message.senderUserID == currentUser?.id
    }
    
    private var displayName: String {
        isCurrentUser
        ? (currentUser?.nickname ?? "Yo")
        : (friendUser?.nickname  ?? "Usuario")
    }
    
    private var avatarURL: URL? {
        URL(string: isCurrentUser
            ? (currentUser?.imgUrl ?? "")
            : (friendUser?.imgUrl  ?? ""))
    }
    
    
    
    // Bindings recibidos desde `PrivateChatView`
    @Binding var messageText: String
    @Binding var isEditing: Bool
    @Binding var editingMessageID: String?
    @Binding var replyingToMessageID: String?
    @Binding var replyingToNickname: String?
    @Bindable var userProfileView: NewAccountViewModel = .init()
    
    
    // Colores para el remitente y el receptor
    private var bubbleColor: Color {
        isCurrentUser ? .green.opacity(0.7) : .cyan.opacity(0.7)
    }
    
    
    
    var body: some View {
        
        // Condicional para llasmar a las reaccione emojis
        if isEmojiPickerVisible{
            ScrollView(.horizontal, showsIndicators: false){
                HStack(spacing: 8){
                    ForEach(EmojiData.emojiCategories["Reacciones"] ?? [], id: \.self) { emoji in
                        
                        Button(action: {
                            Task{
                                if message.reactions?[Auth.auth().currentUser?.uid ?? ""] == emoji{
                                    await privateChatViewModel.reacToMessageRemove(from: chatID, messageID: message.id)
                                }else{
                                    
                                    await  privateChatViewModel.addReacToMessage(chatsID: chatID,messageID: message.id, emoji: emoji, userID: message.senderUserID)
                                }
                                
                                isEmojiPickerVisible = false
                            }
                        }){
                            Text(emoji).font(.largeTitle)
                        }
                    }
                }.background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.gray.opacity(0.45))
                        .stroke(Color.black.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)
            }
            .transition(.opacity)
        }
        
        if message.content == "Mensaje eliminado" {
            HStack {
                Spacer()
                Text("\(privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? "Tú" : user?.nickname ?? "Usuario") eliminó este mensaje")
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                Spacer()
            }
        }else {
            HStack(alignment: .bottom, spacing: 10) {
                
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: -10) {
                    VStack(alignment: .leading) {
                        Text(displayName)
                            .font(.footnote.bold())
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                        
                        
                        Rectangle() // line de separación
                            .fill(.black.opacity(0.60))
                            .frame(width: 250, height: 1, alignment: .center)
                        
                        // Caja de referencia si es respuesta ........
                        if let replyText = message.replyingToText, let replyNickname = message.replyingToNickname {
                            HStack {
                                Rectangle().fill(.orange)
                                    .frame(width: 3, height: 60)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(replyNickname)")
                                        .font(.caption.bold())
                                    Rectangle()
                                        .fill(.black.opacity(0.60))
                                        .frame(width: 250, height: 1, alignment: .center)
                                        .padding(.vertical, 10)
                                    
                                    Text("\(replyText)")
                                        .font(.caption2)
                                        .lineLimit(2)
                                }
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white.opacity(0.35))
                                    .stroke(Color.black.opacity(0.5), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        switch message.type{
                        case .audio:
                            AudioMessageView(
                                audioURLString: message.content,
                                duration: message.audioDuration ?? 0,
                                chatAudioViewModel: chatAudioViewModel
                            )
                            
                            // aqui se le añade los caso oae compartir audio, imagenes...
                        default:
                            Text(message.content)
                                .padding(.horizontal, 10)
                        }
                        
                        // Aqui se pintan las reacciones emojis.
                        if let reactions = message.reactions, !reactions.isEmpty{
                            HStack(spacing: 2){
                                ForEach(Array(Set(reactions.values)), id:\.self){ emoji in
                                    Text(emoji).font(.callout)
                                }
                            }.offset(x: 15, y: 10)
                        }
                        
                        HStack {
                            Spacer()
                            Text(privateChatViewModel.formatTime(from: message.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                        }
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(bubbleColor)
                    )
                    .contextMenu{
                        // boton de ventana modal emogis
                        Button(action: {
                            isEmojiPickerVisible.toggle()
                        }, label: {
                            Text("Emojis")
                            Image(systemName: "face.smiling")
                                .foregroundColor(.yellow)
                        })
                        
                        if isCurrentUser {
                            Button(action: {
                                messageText = message.content
                                editingMessageID = message.id
                                isEditing = true
                            }){
                                Label("Editar", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    do {
                                        try await privateChatViewModel.deleteMessageMark(chatsID: chatID,
                                                                                         messageID: message.id)
                                        let fileURL = try await chatFileViewModel.downloadAndSaveFile(from: message.content)
                                        try FileManager.default.removeItem(at: fileURL)
                                    } catch {
                                        print("Error al eliminar archivo: \(error.localizedDescription)")
                                    }
                                }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }else {
                            Button(action: {
                                replyingToMessageID = message.id
                                replyingToNickname = user?.nickname
                            }, label: {
                                Label("Responder", systemImage: "arrowshape.turn.up.left")
                            })
                        }
                        

                    }
                    if showAvatar {
                        // pico de la burbuja ..
                        TriangleRight()
                            .fill(bubbleColor)
                            .frame(width: 10, height: 10)
                            .offset(x:  -9, y: 10)
                            .scaleEffect( x: isCurrentUser ? 1 : -1, y: 1)
                        
                        // Avatars ...
                        if let url = avatarURL {
                            KFImage(url)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                                .offset(y: 30)
                            
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 30))
                                .offset(y: 30)
                        }
                    }
                    
                }
                .frame(maxWidth: 260, alignment: privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? .trailing : .leading)
                
                .task {
                    await userProfileView.loadUserData()
                    
                }
            }
            .padding(.bottom, showAvatar ? 20 : 0)
        }
    }
}

//#Preview {
//    @Previewable @State var mock = Mock()
//    MessageBubbleView(
//        chatID: "previewChat",
//        message: mock.sampleMessage,
//        user: mock.sampleUser,
//        messageText: .constant(""),
//        isEditing: .constant(false),
//        editingMessageID: .constant(nil)
//    )
//    .environment(PrivateChatViewModel())
//}

