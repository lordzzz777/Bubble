//
//  AddNewFriendViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 2/9/25.
//

import Foundation


@Observable @MainActor
final class AddNewFriendViewModel {
    
    // MARK: - Dependencias
    private let addNewFriendService: AddNewFriendService = AddNewFriendService()
    
    // MARK: - Estado UI
    var matchedUsers: [UserModel] = []
  
    var showError: Bool = false
    var isSuccess = false
    var friendNickname: String = ""
    var successMessage: String = ""
    var errorTitle: String = ""
    var errorDescription: String = ""
    
    // MARK: - Búsqueda
    /// Busca usuarios cuyo `nickname` coincida y actualiza `matchedUsers`.
    func searchFriendByNickname(_ nickname: String) async {
        do {
            matchedUsers = try await addNewFriendService.searchFriendByNickname(nickname)
        } catch {
            errorTitle = "Error al buscar amigos"
            errorDescription = "Ha ocurrido un error al intentar buscar amigos. Por favor, intente más tarde."
            showError = true
        }
    }

    // MARK: - Aceptar solicitud
    /// Acepta una solicitud (chat existente) y añade ambos usuarios como amigos.
    func acceptFriendRequest(chatID: String, senderUID: String) async{
        do{
            try await addNewFriendService.acceptFriendRequest(chatID: chatID, senderUID: senderUID)
            successMessage = "¡Solicitud de amistad aceptada!"
            isSuccess = true
        }catch{
            errorTitle = ""
            errorDescription = ""
            showError = true
        }
    }
}
