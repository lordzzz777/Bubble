//
//  ReportReviewView.swift
//  Bubble
//
//  Created by Codex on 14/7/26.
//

import SwiftUI

struct ReportReviewView: View {
    @State private var moderationViewModel = ModerationViewModel()
    @State private var selectedReport: ReportModel?
    @State private var resolutionNote = ""
    @State private var selectedStatus: ReportStatus = .reviewed
    
    var body: some View {
        Group {
            if moderationViewModel.canReviewReports {
                reportsList
            } else if moderationViewModel.isLoading {
                ProgressView()
            } else {
                ContentUnavailableView(
                    "Acceso restringido",
                    systemImage: "lock.shield",
                    description: Text("Solo administradores o moderadores pueden revisar reportes.")
                )
            }
        }
        .navigationTitle("Reportes")
        .task {
            await moderationViewModel.loadOpenReports()
        }
        .refreshable {
            await moderationViewModel.loadOpenReports()
        }
        .sheet(item: $selectedReport) { report in
            reviewSheet(report)
        }
        .alert("Error", isPresented: $moderationViewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(moderationViewModel.errorMessage)
        }
    }
    
    private var reportsList: some View {
        List {
            if moderationViewModel.openReports.isEmpty {
                ContentUnavailableView(
                    "Sin reportes abiertos",
                    systemImage: "checkmark.shield",
                    description: Text("No hay reportes pendientes de revisión.")
                )
            } else {
                ForEach(moderationViewModel.openReports) { report in
                    Button {
                        selectedStatus = .reviewed
                        resolutionNote = ""
                        selectedReport = report
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(report.reason.title)
                                .font(.headline)
                            Text(report.isPublicChat ? "Chat público" : "Chat privado")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Usuario reportado: \(report.reportedUserID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func reviewSheet(_ report: ReportModel) -> some View {
        NavigationStack {
            Form {
                Section("Reporte") {
                    LabeledContent("Motivo", value: report.reason.title)
                    LabeledContent("Estado", value: report.status.title)
                    LabeledContent("Reportado", value: report.reportedUserID)
                    LabeledContent("Reporta", value: report.reporterUserID)
                    if let chatID = report.chatID {
                        LabeledContent("Chat", value: chatID)
                    }
                    if let messageID = report.messageID {
                        LabeledContent("Mensaje", value: messageID)
                    }
                }
                
                if !report.details.isEmpty {
                    Section("Detalles") {
                        Text(report.details)
                    }
                }
                
                Section("Resolución") {
                    Picker("Estado", selection: $selectedStatus) {
                        ForEach([ReportStatus.reviewed, .dismissed, .actioned]) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    TextEditor(text: $resolutionNote)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Revisar reporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        selectedReport = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await moderationViewModel.resolveReport(report, status: selectedStatus, note: resolutionNote)
                            selectedReport = nil
                        }
                    }
                    .disabled(moderationViewModel.isLoading)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReportReviewView()
    }
}
