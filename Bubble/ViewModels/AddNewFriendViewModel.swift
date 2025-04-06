//
//  AddNewFriendViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 2/9/25.
//

import Foundation


@Observable @MainActor
class AddNewFriendViewModel {
    private let addNewFriendService: AddNewFriendService = AddNewFriendService()
    
    var matchedUsers: [UserModel] = []
  
    var showError: Bool = false
    var isSuccess = false
    
    var friendNickname: String = ""
    var successMessage: String = ""
    var errorTitle: String = ""
    var errorDescription: String = ""
    
    /// Busca amigos por su nickname y actualiza la lista `matchedUsers`
    /// - Parameter nickname: Nickname que se desea buscar
    func searchFriendByNickname(_ nickname: String) async {
        do {
            matchedUsers = try await addNewFriendService.searchFriendByNickname(nickname)
        } catch {
            errorTitle = "Error al buscar amigos"
            errorDescription = "Ha ocurrido un error al intentar buscar amigos. Por favor, intente más tarde."
            showError = true
        }
    }

    /// Función para aceptar solicitud de amistad
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
