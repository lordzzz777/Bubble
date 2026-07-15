//
//  ModerationViewModel.swift
//  Bubble
//
//  Created by Codex on 14/7/26.
//

import Foundation

@Observable
@MainActor
final class ModerationViewModel {
    private let service = ModerationService()
    
    var isBlocked = false
    var isLoading = false
    var showError = false
    var errorMessage = ""
    var canReviewReports = false
    var openReports: [ReportModel] = []
    
    func loadBlockStatus(userID: String) async {
        do {
            isBlocked = try await service.isBlocked(userID)
        } catch {
            setError("No se pudo comprobar el bloqueo.")
        }
    }
    
    func block(userID: String) async {
        await runAction {
            try await service.blockUser(userID)
            isBlocked = true
        }
    }
    
    func unblock(userID: String) async {
        await runAction {
            try await service.unblockUser(userID)
            isBlocked = false
        }
    }
    
    func report(
        reportedUserID: String,
        messageID: String?,
        chatID: String?,
        isPublicChat: Bool,
        reason: ReportReason,
        details: String
    ) async -> Bool {
        do {
            isLoading = true
            defer { isLoading = false }
            try await service.submitReport(
                reportedUserID: reportedUserID,
                messageID: messageID,
                chatID: chatID,
                isPublicChat: isPublicChat,
                reason: reason,
                details: details
            )
            return true
        } catch {
            setError("No se pudo enviar el reporte.")
            return false
        }
    }
    
    func loadModerationAccess() async {
        do {
            canReviewReports = try await service.currentUserCanReviewReports()
        } catch {
            canReviewReports = false
        }
    }
    
    func loadOpenReports() async {
        do {
            isLoading = true
            defer { isLoading = false }
            openReports = try await service.fetchOpenReports()
            canReviewReports = true
        } catch {
            canReviewReports = false
            setError("No se pudieron cargar los reportes.")
        }
    }
    
    func resolveReport(_ report: ReportModel, status: ReportStatus, note: String) async {
        await runAction {
            try await service.resolveReport(reportID: report.id, status: status, resolutionNote: note)
            openReports.removeAll { $0.id == report.id }
        }
    }
    
    private func runAction(_ action: () async throws -> Void) async {
        do {
            isLoading = true
            defer { isLoading = false }
            try await action()
        } catch {
            setError("No se pudo completar la acción.")
        }
    }
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
