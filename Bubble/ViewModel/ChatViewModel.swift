//
//  ChatViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/2/25.
//

import Foundation
import FirebaseFirestore
import Observation

@Observable
class ChatViewModel{
    var chats: [ChatsModels] = []
    private let chatService = FirebaseService()
    
    @MainActor
    func loadChats() async {
        do {
            let fetchedChats = try await chatService.fetchChats()
            self.chats = fetchedChats
        } catch {
            print("❌ Error al cargar los chats: \(error.localizedDescription)")
        }
    }
    
}
