//
//  ChatViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/2/25.
//

import Foundation
import FirebaseFirestore
import Observation

class ChatViewModel{
    var chats: [ChatsModels] = []
    private let chatService = FirebaseService()

    // 🔹 Función asíncrona para cargar la lista de chats
    @MainActor
    func loadChas() async{
        do{
            let fetchedChats = try await chatService.fetchChat()
            self.chats = fetchedChats
        }catch {
            print("❌ Error al cargar los chats: \(error.localizedDescription)")
        }
    }
}
