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
            VStack {
                Text(message.content)
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
        .frame(maxWidth: .infinity, alignment: privateChatViewModel.checkIfMessageWasSentByCurrentUser(message) ? .leading : .trailing)
    }
}

#Preview {
    MessageBubbleView(message: .init(id: "84iKQucP0pOCPOFOp4Db", senderUserID: "1UAaH1mnl6XOQbPJqNz6qnnN8ku1", content: "Hola. Cómo estás?", timestamp: .init(), type: MessageType.text))
}
