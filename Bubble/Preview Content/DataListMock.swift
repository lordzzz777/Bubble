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

@Observable
class Mock {
    
    // ─── Mensaje de ejemplo ──────────────────────────────────────────────
    let sampleMessage = MessageModel(
        id: "84iKQucP0pOCPOFOp4Db",
        senderUserID: "1UAaH1mnl6XOQbPJqNz6qnnN8ku1",
        content: "Hola. ¿Cómo estás?",
        timestamp: Timestamp(),          // ahora mismo
        type: .text
    )
    
    // ─── Usuario de ejemplo ─────────────────────────────────────────────
    let sampleUser = UserModel(
        id: "ZvwqAdAu9uhXmmDrXuWXCosfuNC2",
        nickname: "Lordzzz",
        imgUrl: "https://example.com/avatar.png",
        lastConnectionTimeStamp: Timestamp(),
        isOnline: true,
        chats: [],
        friends: [],
        isDeleted: false
    )
}
