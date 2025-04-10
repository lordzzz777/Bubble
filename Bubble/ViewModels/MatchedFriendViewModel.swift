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

@Observable @MainActor
class MatchedFriendViewModel {
    private var addNewFriendService: AddNewFriendService = AddNewFriendService()
    var friendRequestStatus: FriendRequestStatus = .none
    var loadingData: Bool = false
    
    var showError: Bool = false
    var errorTitle: String = ""
    var errorDescription: String = ""
    
    /// Envía una solicitud de amistad al usuario con el UID especificado
    /// - Parameter friendUID: UID del amigo al que se desea enviar la solicitud
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
    
    func cancelFriendRequest(friendUID: String) async {
        do {
            try await addNewFriendService.cancelFriendRequest(friendUID: friendUID)
            withAnimation(.bouncy(duration: 0.3)) {
                friendRequestStatus = .none
            }
        } catch {
            errorTitle = "Error al cancelar solicitud de amistad"
            errorDescription = "Ha ocurrido un error al intentar cancelar la solicitud de amistad. Por favor, intente más tarde."
            showError = true
        }
    }
    
    func deleteFriend(friendUID: String) async {
        do {
            try await addNewFriendService.deleteFriend(friendUID: friendUID)
            withAnimation(.bouncy(duration: 0.3)) {
                friendRequestStatus = .none
            }
        } catch {
            errorTitle = "Error al eliminar amigo"
            errorDescription = "Ha ocurrido un error al intentar eliminar al amigo. Por favor, intente más tarde."
            showError = true
        }
    }
    
    func checkIfFriendRequestPending(friendUID: String) async {
        do {
            let isPending = try await addNewFriendService.checkFriendIfFriendRequestPending(friendUID: friendUID)
            if isPending {
                friendRequestStatus = .pending
            }
        } catch {
            errorTitle = "Error al verificar el estado de la solicitud de amistad"
            errorDescription = "Ha ocurrido un error al intentar verificar el estado de la solicitud de amistad. Por favor, intente más tarde."
            showError = true
        }
    }
    
    func checkIfFriend(friendUID: String) async {
        do {
            let isFriend = try await addNewFriendService.checkIfFriend(friendUID: friendUID)
            if isFriend {
                friendRequestStatus = .accepted
            }
        } catch {
            errorTitle = "Error al verificar si son amigos"
            errorDescription = "Ha ocurrido un error al intentar verificar si son amigos. Por favor, intente más tarde."
            showError = true
        }
    }
}
