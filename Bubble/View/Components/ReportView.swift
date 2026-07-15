//
//  ReportView.swift
//  Bubble
//
//  Created by Codex on 14/7/26.
//

import SwiftUI

struct ReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var moderationViewModel = ModerationViewModel()
    @State private var selectedReason: ReportReason = .spam
    @State private var details = ""
    
    let reportedUserID: String
    let messageID: String?
    let chatID: String?
    let isPublicChat: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Motivo") {
                    Picker("Motivo", selection: $selectedReason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.title).tag(reason)
                        }
                    }
                }
                
                Section("Detalles opcionales") {
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Reportar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let didReport = await moderationViewModel.report(
                                reportedUserID: reportedUserID,
                                messageID: messageID,
                                chatID: chatID,
                                isPublicChat: isPublicChat,
                                reason: selectedReason,
                                details: details
                            )
                            if didReport {
                                dismiss()
                            }
                        }
                    } label: {
                        if moderationViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Enviar")
                        }
                    }
                    .disabled(moderationViewModel.isLoading)
                }
            }
            .alert("Error", isPresented: $moderationViewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(moderationViewModel.errorMessage)
            }
        }
    }
}

#Preview {
    ReportView(
        reportedUserID: "user_mock",
        messageID: "message_mock",
        chatID: "chat_mock",
        isPublicChat: false
    )
}
