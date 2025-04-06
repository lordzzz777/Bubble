//
//  MatchedFriendViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 4/5/25.
//

import Foundation
import SwiftUI

enum FriendRequestStatus {
    case none
    case pending
    case accepted
}

@Observable
class MatchedFriendViewModel {
    private var addNewFriendService: AddNewFriendService = AddNewFriendService()
    var friendRequestStatus: FriendRequestStatus = .none
    var loadingData: Bool = false
    
    var showError: Bool = false
    var errorTitle: String = ""
    var errorDescription: String = ""
    
    /// Envía una solicitud de amistad al usuario con el UID especificado
    /// - Parameter friendUID: UID del amigo al que se desea enviar la solicitud
    @MainActor
    func sendFriendRequest(friendUID: String) async {
        Task {
            do {
                try await addNewFriendService.sendFriendRequest(friendUID: friendUID)
                
                withAnimation(.bouncy(duration: 0.3)) {
                    friendRequestStatus = .pending
                }
            } catch {
                errorTitle = "Error al enviar solicitud de amistad"
                errorDescription = "Ha ocurrido un error al intentar enviar una solicitud de amistad. Por favor, intente más tarde."
                showError = true
            }
        }
    }
    
    @MainActor
    func checkFriendRequestStatus(friendUID: String) async {
        do {
            let isPending = try await addNewFriendService.checkFriendIfFriendRequestPending(friendUID: friendUID)
            print("Estado de la solicitud de amistad: \(isPending)")
            friendRequestStatus = isPending ? .pending : .none
        } catch {
            errorTitle = "Error al verificar el estado de la solicitud de amistad"
            errorDescription = "Ha ocurrido un error al intentar verificar el estado de la solicitud de amistad. Por favor, intente más tarde."
            showError = true
        }
    }
}
