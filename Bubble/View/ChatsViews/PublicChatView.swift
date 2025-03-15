//
//  PublicChatView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 11/3/25.
//

import SwiftUI

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PublicChatView: View {
    @State private var publicChatViewModel = ChatsViewModel()
    @State private var messageText: String = ""
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(publicChatViewModel.messages, id: \.id) { message in
                            MessageBubbleView(message: message)
                        }
                    }
                    .padding(.bottom, 20)
                    .onChange(of: publicChatViewModel.messages) { _,_ in
                        withAnimation {
                            if let lastMessage = publicChatViewModel.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                TextField("Escribe tu mensaje...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 40)
                
                Button(action: {
                    if !messageText.isEmpty {
                        Task {
                            await publicChatViewModel.sendPublicMessage(messageText)
                            messageText = ""
                        }
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .navigationTitle("Chat Público")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            publicChatViewModel.fetchPublicChatMessages()
        }
    }
}


#Preview {
    PublicChatView()
}
