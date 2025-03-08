//
//  MessageBubbleView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/4/25.
//

import SwiftUI


struct MessageBubbleView: View {
    
    var message: MessageModel
    
    @State private var privateChatViewModel = PrivateChatViewModel()
    
    var body: some View {
        VStack {
            HStack {
                Text(message.content)
                
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
    }
}

#Preview {
    MessageBubbleView(message: .init(id: "84iKQucP0pOCPOFOp4Db", senderUserID: "1UAaH1mnl6XOQbPJqNz6qnnN8ku1", content: "Hola. Cómo estás?", timestamp: .init(), type: MessageType.text))
}
