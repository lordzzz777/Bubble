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
        do {
            let imageURL = try await createCommunityService.uploadImage(image: image, communityID: community.id)
            community.imgUrl = imageURL
        } catch {
            errorTitle = "Hubo un error al subir la imagen"
            errorMessage = "Lo sentimos. Hubo un error al intentar subir la imagen al servidor. Por favor, intenta más tarde."
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
        withAnimation(.bouncy) {
            return community.members.contains(where: { $0 == friendID })
        }
    }
    
    /// Borra de Storage la imagen asociada (rollback o cambio).
    func removeImageFromFirebaseStorage(imageURL: String) async {
        do {
            try await createCommunityService.removeImageFromFirebaseStorage(imageURL: imageURL)
            print("Imagen de comunidad eliminada con éxito")
        } catch {
            errorTitle = "Error al eliminar imagen de la communidad"
            errorMessage = "Hubo un error al intentar validar el nombre de la comunidad. Por favor, intenta más tarde."
            print("Error al eliminar imagen de la communidad: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Creación
    
    /// Crea la comunidad y envía invitaciones. Devuelve `true` si todo OK.
    func createCommunity(newCommunity: CommunityModel) async -> Bool {
        do {
            isCreatingCommunity = true
            let friendsToInviteIDs: [String] = friendsToInvite.map({$0.id})
            try await createCommunityService.createCommunity(community: newCommunity, friendToInviteIDs: friendsToInviteIDs)
            isCreatingCommunity = false
            return true
        } catch {
            errorTitle = "Error al crear la comunidad"
            errorMessage = "Hubo un error al intentar crear la comunidad. Por favor, intenta más tarde."
            showError = true
            isCreatingCommunity = false
        }
        
        return false
    }
}
