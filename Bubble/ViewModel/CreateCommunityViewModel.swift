//
//  CreateCommunityViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/12/25.
//

import Foundation
import SwiftUI

@Observable
class CreateCommunityViewModel {
    private let createCommunityService: CreateCommunityService = CreateCommunityService()
    var community: CommunityModel = CommunityModel(name: "", imgUrl: "", createdAt: .init(), ownerUID: "", lastMessage: "", messages: [], admins: [], members: [], blockedUsers: [])
    
    var friendsToInvite: [UserModel] = []
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
    
    @MainActor
    func uploadImage(image: UIImage) async {
        do {
            let imageURL = try await createCommunityService.uploadImage(image: image, communityID: community.id)
            community.imgUrl = imageURL
        } catch {
            errorTitle = "Hubo un error al subir la imagen"
            errorMessage = "Lo sentimos. Hubo un error al intentar subir la imagen al servidor. Por favor, intenta más tarde."
            showError = true
        }
    }
}
