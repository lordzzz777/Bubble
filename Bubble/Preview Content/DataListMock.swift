//
//  DataListMock.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 30/1/25.
//

import Foundation
import FirebaseFirestore

//struct ModelListMock: Identifiable {
//    var id = UUID()
//    var nameAlias: String
//    var nameImage: String
//    var dataTimer: String
//}
//
//@MainActor let dataList: [ModelListMock] = [
//  .init(nameAlias: "TopGum", nameImage: "topgum", dataTimer: "01:50"),
//    .init(nameAlias: "Peterete", nameImage: "peterete", dataTimer: "18:20"),
//    .init(nameAlias: "Paloma23", nameImage: "paloma", dataTimer: "16:30"),
//    .init(nameAlias: "Yeikobu", nameImage: "yey", dataTimer: "09:30"),
//    .init(nameAlias: "Lordzzz", nameImage: "lordzzz", dataTimer: "10:15")/*,
//    .init(nameAlias: "Lovezno", nameImage: "lovezno", dataTimer: "11:00"),
//    .init(nameAlias: "Monica36", nameImage: "monica", dataTimer: "20:07"),
//    .init(nameAlias: "Veronica27", nameImage: "veronica", dataTimer: "21:07")*/
//]

//@Observable
//class Mock {
//    
//    // ─── Mensaje de ejemplo ──────────────────────────────────────────────
//    let sampleMessage = MessageModel(
//        id: "84iKQucP0pOCPOFOp4Db",
//        senderUserID: "1UAaH1mnl6XOQbPJqNz6qnnN8ku1",
//        content: "Hola. ¿Cómo estás?",
//        timestamp: Timestamp(),          // ahora mismo
//        type: .text
//    )
//    
//    // ─── Usuario de ejemplo ─────────────────────────────────────────────
//    let sampleUser = UserModel(
//        id: "ZvwqAdAu9uhXmmDrXuWXCosfuNC2",
//        nickname: "Lordzzz",
//        imgUrl: "https://example.com/avatar.png",
//        lastConnectionTimeStamp: Timestamp(),
//        isOnline: true,
//        chats: [],
//        friends: [],
//        isDeleted: false
//    )
//}

#if DEBUG
import FirebaseFirestore          // para Timestamp

/// Datos de prueba para vistas Preview.
struct Mock {
    
    // ⚪️ Usuario actual
    let currentUser = UserModel(
        id:                     "user_me",
        nickname:               "Yo",
        imgUrl:                 "",
        lastConnectionTimeStamp: Timestamp(date: .now),
        isOnline:               true,
        chats:                  [],
        friends:                [],
        isDeleted:              false
    )
    
    // 🟣 Amigo con el que chateamos
    let friendUser = UserModel(
        id:                     "user_friend",
        nickname:               "Ana",
        imgUrl:                 "",
        lastConnectionTimeStamp: Timestamp(date: .now),
        isOnline:               true,
        chats:                  [],
        friends:                [],
        isDeleted:              false
    )
    
    // ✉️ Mensaje PDF
    let samplePDFMessage = MessageModel(
        id:             "m1",
        senderUserID:   "user_friend",
        content:        "https://example.com/ejemplo.pdf",
        timestamp:      Timestamp(date: .now),
        type:           .file
    )
    
    // ✉️ Mensaje de audio
    let sampleAudioMessage = MessageModel(
        id:             "m2",
        senderUserID:   "user_me",
        content:        "https://example.com/nota.m4a",
        timestamp:      Timestamp(date: .now),
        type:           .audio,
        audioDuration:  12.3
    )
    
    // ✉️ Mensaje de texto
    let sampleTextMessage = MessageModel(
        id:             "m3",
        senderUserID:   "user_friend",
        content:        "¡Hola! Este es un mensaje de prueba 🤖",
        timestamp:      Timestamp(date: .now),
        type:           .text
    )
}
#endif
