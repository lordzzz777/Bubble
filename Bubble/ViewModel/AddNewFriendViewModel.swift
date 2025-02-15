//
//  AddNewFriendViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 2/9/25.
//

import Foundation

@Observable
class AddNewFriendViewModel {
    private let addNewFriendService: AddNewFriendService = AddNewFriendService()
    
    var friendNickname: String = ""
    var matchedUsers: [UserModel] = []
    var showError: Bool = false
    var errorTitle: String = ""
    var errorDescription: String = ""
    
    @MainActor
    func searchFriendByNickname(_ nickname: String) async {
        do {
            matchedUsers = try await addNewFriendService.searchFriendByNickname(nickname)
            print("Usuarios encontrados por el nickname: \(nickname): \(matchedUsers.map(\.nickname))")
        } catch {
            errorTitle = "Error al buscar amigos"
            errorDescription = "Ha ocurrido un error al intentar buscar amigos. Por favor, intente más tarde."
            showError = true
        }
    }
    
    @MainActor
    func sendFriendRequest(friendUID: String) async {
        Task {
            do {
                try await addNewFriendService.sendFriendRequest(friendUID: friendUID)
            } catch {
                errorTitle = "Error al enviar solicitud de amistad"
                errorDescription = "Ha ocurrido un error al intentar enviar una solicitud de amistad. Por favor, intente más tarde."
                showError = true
            }
        }
    }
}
