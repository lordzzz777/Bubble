//
//  ReportModel.swift
//  Bubble
//
//  Created by Codex on 14/7/26.
//

import Foundation
import FirebaseFirestore

enum ReportStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case reviewed
    case dismissed
    case actioned
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .open:
            "Abierto"
        case .reviewed:
            "Revisado"
        case .dismissed:
            "Descartado"
        case .actioned:
            "Acción tomada"
        }
    }
}

struct ReportModel: Codable, Identifiable, Hashable {
    var id: String
    var reporterUserID: String
    var reportedUserID: String
    var messageID: String?
    var chatID: String?
    var isPublicChat: Bool
    var reason: ReportReason
    var details: String
    var timestamp: Timestamp
    var status: ReportStatus
    var reviewedByUserID: String?
    var reviewedAt: Timestamp?
    var resolutionNote: String?
}
