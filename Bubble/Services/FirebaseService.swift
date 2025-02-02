//
//  FirebaseService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 1/31/25.
//
//
//  Created by Esteban Pérez Castillejo on 1/2/25.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

actor FirebaseService {
    private let db = Firestore.firestore()
    
    
    // Traerme los chas de este usuario en tiempo real
    // Leer documentacion de Fire Stora
    func fetchChat() async throws -> [ChatsModels] {
        let chatsRef = db.collection("chats")
        
        do{
            let snshop = try await chatsRef.getDocuments()
            let chats = snshop.documents.compactMap { doc -> ChatsModels? in
                try? doc.data(as: ChatsModels.self)
            }
            return chats
        }catch{
            print("❌ Error al obtener los chats: \(error.localizedDescription)")
            throw error
        }
    }
}
