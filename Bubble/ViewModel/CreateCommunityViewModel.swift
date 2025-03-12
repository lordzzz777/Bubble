//
//  CreateCommunityViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/12/25.
//

import Foundation

@Observable
class CreateCommunityViewModel {
    private let createCommunityService: CreateCommunityService = CreateCommunityService()
    var friends: [UserModel] = []
    var showCreateNewCommunity: Bool = false
    
    var showError: Bool = false
    var errorTitle: String = ""
    var errorMessage: String = ""
    
    @MainActor
    func fetchFriends() async -> [UserModel] {
        var friends: [UserModel] = []
        do {
            friends = try await createCommunityService.fetchFriends()
        } catch {
            errorTitle = "Error al intentar obtener amigos"
            errorMessage = "Hubo un error al intentar obtener información de tus amigos. Por favor, intenta más tarde."
            showError = true
        }
        
        return friends
    }
}
