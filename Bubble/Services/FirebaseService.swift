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

    
    // Traerme los chas de este usuario en tiempo real
    // Leeer documentacion de Fire Stora
    func fetchMessages(for chatID: String, completion: @escaping([MessagesModels]) -> Void){
        
        let db = Firestore.firestore()
        let messageRef = db.collection("chats").document(chatID).collection("messages")
        
        messageRef.order(by: "timestamp", descending: false).getDocuments{ snapshot, error in
            guard let document = snapshot?.documents, error == nil else {
                print("error al optener Mensaje: \(error?.localizedDescription ?? "Desconocido")")
                completion([])
                return
            }
            let messages = document.compactMap { doc -> MessagesModels? in
                try? doc.data(as: MessagesModels.self)
            }
            
            completion(messages)
        }
    }
}
