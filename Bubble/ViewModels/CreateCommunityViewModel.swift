//
//  CreateCommunityViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/12/25.
//

import Foundation
import SwiftUI

@Observable @MainActor
final class CreateCommunityViewModel {
    
    // MARK: - Dependencias y estado
    
    private let createCommunityService: CreateCommunityService = CreateCommunityService()
    
    /// Modelo en construcción
    var community: CommunityModel = CommunityModel(
        name: "",
        imgUrl: "",
        createdAt: .init(),
        ownerUID: "",
        lastMessage: "",
        messages: [],
        admins: [],
        members: [],
        blockedUsers: [],
        admissionRequests: []
    )
    
    /// Amigos elegidos para invitar
    var friendsToInvite: [UserModel] = []
    
    /// Flags de UI
    var showCreateNewCommunity: Bool = false
    var isCreatingCommunity: Bool = false
    var isUploadingImage: Bool = false
    
    /// Gestión de errores
    var showError: Bool = false
    var errorTitle: String = ""
    var errorMessage: String = ""
    
    // MARK: - Datos
    
    /// Descarga la lista de amigos del usuario.
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
    
    /// Sube la imagen de la comunidad y actualiza `community.imgUrl`.
    func uploadImage(image: UIImage) async {
        isUploadingImage = true
        defer { isUploadingImage = false }
        do {
            let imageURL = try await createCommunityService.uploadImage(image: image, communityID: community.id)
            community.imgUrl = imageURL
        } catch {
            errorTitle = "Hubo un error al subir la imagen"
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    /// Verifica que el nombre no esté ya registrado.
    func checkIfCommunityNameExists(communityName: String) async -> Bool {
        do {
            return try await createCommunityService.checkIfCommunityNotExistsBy(name: communityName)
        } catch {
            errorTitle = "Error al validar el nombre de la comunidad"
            errorMessage = "Hubo un error al intentar validar el nombre de la comunidad. Por favor, intenta más tarde."
            showError = true
            return false
        }
    }
    
    /// Devuelve `true` si el amigo está marcado para invitar
    func checkIfFriendIsSelected(friendID: String) -> Bool {
        community.members.contains(where: { $0 == friendID })
    }
    
    func toggleMemberSelection(friendID: String) {
        if community.members.contains(friendID) {
            community.members.removeAll(where: { $0 == friendID })
        } else {
            community.members.append(friendID)
        }
    }
    
    /// Borra de Storage la imagen asociada (rollback o cambio).
    func removeImageFromFirebaseStorage(imageURL: String) async {
        do {
            try await createCommunityService.removeImageFromFirebaseStorage(imageURL: imageURL)
            AppLogger.debug("Imagen de comunidad eliminada.")
        } catch {
            errorTitle = "Error al eliminar imagen de la communidad"
            errorMessage = "Hubo un error al intentar validar el nombre de la comunidad. Por favor, intenta más tarde."
            AppLogger.error("Error al eliminar imagen de la comunidad.")
        }
    }
    
    // MARK: - Creación
    
    /// Crea la comunidad y envía invitaciones. Devuelve `true` si todo OK.
    func createCommunity(newCommunity: CommunityModel, image: UIImage?) async -> Bool {
        do {
            isCreatingCommunity = true
            defer { isCreatingCommunity = false }

            var communityToCreate = newCommunity
            if let image {
                isUploadingImage = true
                defer { isUploadingImage = false }
                communityToCreate.imgUrl = try await createCommunityService.uploadImage(
                    image: image,
                    communityID: communityToCreate.id
                )
            }

            let friendsToInviteIDs = communityToCreate.members
            try await createCommunityService.createCommunity(
                community: communityToCreate,
                friendToInviteIDs: friendsToInviteIDs
            )
            community = communityToCreate
            return true
        } catch {
            errorTitle = "Error al crear la comunidad"
            errorMessage = error.localizedDescription
            showError = true
        }
        
        return false
    }
}
