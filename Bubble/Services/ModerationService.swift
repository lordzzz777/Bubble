//
//  ModerationService.swift
//  Bubble
//
//  Created by Codex on 14/7/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum ModerationError: LocalizedError {
    case blockedInteraction
    case unauthenticated
    case chatNotAvailable
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .blockedInteraction:
            "No se puede enviar porque hay un bloqueo activo entre los usuarios."
        case .unauthenticated:
            "No hay usuario autenticado."
        case .chatNotAvailable:
            "El chat no está disponible."
        case .notAuthorized:
            "No tienes permisos de moderación."
        }
    }
}

enum ReportReason: String, Codable, CaseIterable, Identifiable {
    case spam
    case harassment
    case sexualContent
    case violence
    case hate
    case other
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .spam:
            "Spam o estafa"
        case .harassment:
            "Acoso o amenazas"
        case .sexualContent:
            "Contenido sexual"
        case .violence:
            "Violencia"
        case .hate:
            "Odio o discriminación"
        case .other:
            "Otro motivo"
        }
    }
}

actor ModerationService {
    private let database = Firestore.firestore()
    
    private var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }
    
    func blockUser(_ userID: String) async throws {
        guard let currentUserID, currentUserID != userID else { return }
        try await database.collection("users").document(currentUserID).updateData([
            "blockedUsers": FieldValue.arrayUnion([userID])
        ])
    }
    
    func unblockUser(_ userID: String) async throws {
        guard let currentUserID else { return }
        try await database.collection("users").document(currentUserID).updateData([
            "blockedUsers": FieldValue.arrayRemove([userID])
        ])
    }
    
    func isBlocked(_ userID: String) async throws -> Bool {
        guard let currentUserID else { return false }
        let document = try await database.collection("users").document(currentUserID).getDocument()
        let blockedUsers = document.data()?["blockedUsers"] as? [String] ?? []
        return blockedUsers.contains(userID)
    }
    
    func blockedUserIDs() async throws -> Set<String> {
        guard let currentUserID else { return [] }
        let document = try await database.collection("users").document(currentUserID).getDocument()
        let blockedUsers = document.data()?["blockedUsers"] as? [String] ?? []
        return Set(blockedUsers)
    }
    
    func assertCanStartPrivateChat(with userID: String) async throws {
        guard let currentUserID else {
            throw ModerationError.unauthenticated
        }
        guard currentUserID != userID else { return }
        
        let currentUserSnapshot = try await database.collection("users").document(currentUserID).getDocument()
        let currentUserBlockedUsers = currentUserSnapshot.data()?["blockedUsers"] as? [String] ?? []
        if currentUserBlockedUsers.contains(userID) {
            throw ModerationError.blockedInteraction
        }
        
        let otherUserSnapshot = try await database.collection("users").document(userID).getDocument()
        let otherUserBlockedUsers = otherUserSnapshot.data()?["blockedUsers"] as? [String] ?? []
        if otherUserBlockedUsers.contains(currentUserID) {
            throw ModerationError.blockedInteraction
        }
    }
    
    func assertCanSendPrivateMessage(chatID: String) async throws {
        guard let currentUserID else {
            throw ModerationError.unauthenticated
        }
        
        let chatSnapshot = try await database.collection("chats").document(chatID).getDocument()
        guard let chatData = chatSnapshot.data(),
              let participants = chatData["participants"] as? [String],
              participants.contains(currentUserID) else {
            throw ModerationError.chatNotAvailable
        }
        
        let currentUserSnapshot = try await database.collection("users").document(currentUserID).getDocument()
        let currentUserBlockedUsers = currentUserSnapshot.data()?["blockedUsers"] as? [String] ?? []
        let otherParticipantIDs = participants.filter { $0 != currentUserID }
        
        if otherParticipantIDs.contains(where: { currentUserBlockedUsers.contains($0) }) {
            throw ModerationError.blockedInteraction
        }
        
        for participantID in otherParticipantIDs {
            let participantSnapshot = try await database.collection("users").document(participantID).getDocument()
            let participantBlockedUsers = participantSnapshot.data()?["blockedUsers"] as? [String] ?? []
            if participantBlockedUsers.contains(currentUserID) {
                throw ModerationError.blockedInteraction
            }
        }
    }
    
    func submitReport(
        reportedUserID: String,
        messageID: String?,
        chatID: String?,
        isPublicChat: Bool,
        reason: ReportReason,
        details: String
    ) async throws {
        guard let currentUserID, currentUserID != reportedUserID else { return }
        let reportID = UUID().uuidString
        try await database.collection("reports").document(reportID).setData([
            "id": reportID,
            "reporterUserID": currentUserID,
            "reportedUserID": reportedUserID,
            "messageID": messageID as Any,
            "chatID": chatID as Any,
            "isPublicChat": isPublicChat,
            "reason": reason.rawValue,
            "details": details.trimmingCharacters(in: .whitespacesAndNewlines),
            "timestamp": Timestamp(),
            "status": ReportStatus.open.rawValue
        ])
    }
    
    func currentUserCanReviewReports() async throws -> Bool {
        guard let user = Auth.auth().currentUser else {
            throw ModerationError.unauthenticated
        }
        let token = try await user.getIDTokenResult(forcingRefresh: true)
        let isAdmin = token.claims["admin"] as? Bool ?? false
        let isModerator = token.claims["moderator"] as? Bool ?? false
        return isAdmin || isModerator
    }
    
    func fetchOpenReports(limit: Int = 50) async throws -> [ReportModel] {
        guard try await currentUserCanReviewReports() else {
            throw ModerationError.notAuthorized
        }
        
        let snapshot = try await database.collection("reports")
            .whereField("status", isEqualTo: ReportStatus.open.rawValue)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            var report = try? document.data(as: ReportModel.self)
            report?.id = document.documentID
            return report
        }
    }
    
    func resolveReport(reportID: String, status: ReportStatus, resolutionNote: String) async throws {
        guard let currentUserID else {
            throw ModerationError.unauthenticated
        }
        guard status != .open else { return }
        guard try await currentUserCanReviewReports() else {
            throw ModerationError.notAuthorized
        }
        
        try await database.collection("reports").document(reportID).updateData([
            "status": status.rawValue,
            "reviewedByUserID": currentUserID,
            "reviewedAt": Timestamp(),
            "resolutionNote": resolutionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        ])
    }
}
