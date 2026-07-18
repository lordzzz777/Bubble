//
//  NewAccountViewModel.swift
//  Bubble
//
//  Created by Jacob Aguilar on 1/31/25.
//

import Foundation
import FirebaseAuth
import PhotosUI
import SwiftUI


@Observable @MainActor
final class NewAccountViewModel {
    private let firestoreService: FirestoreService
    private let publicChatService: PublicChatService = PublicChatService()
    
    var uid: String? {
        return Auth.auth().currentUser?.uid
    }

    var user: UserModel?
    var showError: Bool
    var errorTitle: String
    var errorDescription: String
    var showImageUploadError: Bool
    var isShowTemporaryAlert: Bool = false
    var temporaryTitleAlert = ""
    var temporaryMessagesAlert = ""
    
    init(firebaseService: FirestoreService = FirestoreService(), showError: Bool = false, errorTitle: String = "", errorDescription: String = "", showImageUploadError: Bool = false) {
        self.firestoreService = firebaseService
        self.showError = showError
        self.errorTitle = errorTitle
        self.errorDescription = errorDescription
        self.showImageUploadError = showImageUploadError
    }
    
    /// Crea un nuevo usuario en Firestore y lo agrega al chat público.
    ///
    /// - Parameter user: El modelo de usuario que se desea registrar.
    func createUser(user: UserModel) async {
        
        guard let uid = Auth.auth().currentUser?.uid else {
            AppLogger.warning("No hay usuario autenticado.")
            return
        }
        
        do {
            var newUser = user
            newUser.id = uid
            try await firestoreService.createUser(user: newUser)
            try await publicChatService.addUserToPublicChat(userID: uid)
        } catch {
            errorTitle = "Error al crear usuario"
            errorDescription = "Hubo un error al crear el usuario. Inténtelo más tarde."
            showError = true
            AppLogger.error("Ha ocurrido un error al crear el usuario.")
        }
    }
    
    /// Verifica si un nickname ya está en uso en Firestore.
    ///
    /// - Parameter nickName: El nickname que se desea verificar.
    /// - Returns: `true` si el nickname no existe en la base de datos (está disponible),
    ///  `false` si ya está en uso o si ocurre un error.
    func checkNickNameNotExists(nickName: String) async -> Bool {
        do {
            return try await firestoreService.checkIfNicknameNotExists(nickname: nickName)
        } catch {
            showError = true
            errorTitle = "Error al verificar nickname"
            errorDescription = "Hubo un error al comprobar el nickname. Inténtelo más tarde."
            AppLogger.error("Error al comprobar el nombre de usuario.")
            return false
        }
    }
    
    /// Guarda una imagen en el servidor a través del servicio Firestore.
    ///
    /// - Parameter image: La imagen `UIImage` que se desea subir.
    func saveImage(image: UIImage) async {
        do {
            try await firestoreService.saveImage(image: image)
        } catch {
            errorTitle = "Error al cargar la imagen"
            errorDescription = "Hubo un error al subir la imagen al servidor. Inténtelo más tarde."
            showError = true
            showImageUploadError = true
        }
    }
    
    /// Carga los datos del usuario desde Firestore y los almacena en la variable `user`.
    ///
    /// - Nota: Si no se encuentra el usuario, se muestra un mensaje de error en la UI.
    func loadUserData() async{
        do{
            let data = try await firestoreService.getUserData()
            guard let getUser = data else{ return }
            self.user = getUser
        }catch{
            errorTitle = "Error"
            errorDescription = "Usuario no encontrado"
            showError = true
        }
    }
    
    /// Actualiza el nickname del usuario en Firestore.
    ///
    /// - Parameter newNickname: El nuevo nickname que el usuario desea establecer.
    func updateNicname(newNickname: String) async{
        
        do{
            try await firestoreService.updateNickname(newNickname: newNickname)
            self.user?.nickname = newNickname
        }catch{
            showError = true
            errorTitle = "Error al verificar nickname"
            errorDescription = "Hubo un error al comprobar el nickname. Inténtelo más tarde."
            AppLogger.error("Error al comprobar el nombre de usuario.")
        }
    }
    
    /// Muestra una alerta personalizada que desaparece automáticamente después de un tiempo.
    ///
    /// - Parameters:
    ///   - title: El título de la alerta.
    ///   - message: El mensaje que se mostrará en la alerta.
    ///   - seconds: Tiempo en segundos antes de que la alerta se cierre automáticamente (por defecto, 6 segundos).
    func showTemporaryAlert(title: String,  message: String, autoDissmisAfter seconds: Double = 6) async {
        temporaryMessagesAlert = message
        temporaryTitleAlert = title
        
        isShowTemporaryAlert = true
            Task{
                try await Task.sleep(for: .seconds(seconds))
                isShowTemporaryAlert = false
            }
    }
    
    /// Elimina la cuenta del usuario autenticado y sus datos personales asociados.
    func deleteUserAccount() async -> Bool {
        do {
            try await firestoreService.deleteCurrentUserAccount()
            return true
        } catch FirestoreError.requiresRecentLogin {
            showError = true
            errorTitle = "Vuelve a iniciar sesión"
            errorDescription = "Por seguridad, Firebase requiere una autenticación reciente antes de eliminar la cuenta. Cierra sesión, entra de nuevo y repite la eliminación."
            return false
        } catch {
            showError = true
            errorTitle = "Error"
            errorDescription = "No se pudo eliminar la cuenta. Inténtelo más tarde."
            AppLogger.error("Error al eliminar la cuenta.")
            return false
        }
    }
    
    /// Función que devuelve una vista SwiftUI para mostrar y actualizar una imagen de perfil.
    ///
    /// Usa un `Binding` a un `PhotosPickerItem` (para manejar la selección de imagen)
    /// y un Binding a una Image (para mostrar la imagen seleccionada)
    @ViewBuilder
    func profileImage(_ selectedItem:Binding<PhotosPickerItem?>,_ selectedImage: Binding<Image?>) -> some View {
        VStack{
            if let selectedImage = selectedImage.wrappedValue{
                PhotosPicker(selection: selectedItem, photoLibrary: .shared()){
                    selectedImage
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .frame(width: 170, height: 170)
                }
            }else{
                if let imegeURL = user?.imgUrl, let url =  URL(string: imegeURL){
                    PhotosPicker(selection: selectedItem, label: {
                        ComponetImageKFImage(url: url)
                    })
                }else{
                    EmptyView()
                }
            }
        }
        .onChange(of: selectedItem.wrappedValue){ _, newItem in
            Task{ [weak self] in
                guard let self = self else {return}
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage.wrappedValue = Image(uiImage: uiImage)
                    await self.saveImage(image: uiImage)
                    await self.showTemporaryAlert(title: "👤 Foto de perfil", message: "✅ Se ha cambiado con éxito")
                    
                    if self.showImageUploadError {
                        selectedImage.wrappedValue = nil
                    }
                }
            }
        }
    }
    
    /// Vista reutilizable que muestra un botón de selección de imagen (avatar) usando `PhotosPicker`.
    ///
    /// Usa `@ViewBuilder` para permitir condicionales dentro del `body`.
    @ViewBuilder
    func selectAvatarView(_ selectedItem:Binding<PhotosPickerItem?>,_ selectedImage: Binding<Image?>) -> some View{
        VStack{
            if let selectedImage = selectedImage.wrappedValue{
                PhotosPicker(selection: selectedItem,matching: .images, photoLibrary: .shared()){
                    selectedImage
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .frame(width: 170, height: 170)
                }
            }else{
                PhotosPicker(selection: selectedItem, matching: .images, photoLibrary: .shared()){
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.primary)
                        .frame(width: 180, height: 180)
                }
            }
        }
        .onChange(of: selectedItem.wrappedValue) { _, newItem in
            
            Task{ [weak self] in
                guard let self = self else {return}
                
                if let data = try? await newItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data){
                    selectedImage.wrappedValue = Image(uiImage: uiImage)
                    await self.saveImage(image: uiImage)
                    
                    if self.showImageUploadError{
                        selectedImage.wrappedValue = nil
                    }
                }
            }
        }
        
    }
    
}
