//
//  ComminityView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/12/25.
//

import SwiftUI
import PhotosUI
import FirebaseCore

struct CreateCommunityView: View {
    @State private var createCommunityViewModel = CreateCommunityViewModel()
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var communityName: String = ""
    
    var body: some View {
        List {
            Section() {
                SelectAvatarView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } header: {
                Text("Imagen de la comunidad")
            }
            
            Section {
                TextField("Nombre de la comunidad", text: $communityName)
                    .onChange(of: communityName) {
                        
                    }
            } header: {
                Text("Elige el nombre de tu comunidad")
            }
            
            Section {
                ForEach(createCommunityViewModel.friends, id: \.nickname) { friend in
                    FriendToInviteView(friend: friend)
                }
            } header: {
                Text("Elige a los amigos que quieres invitar")
            }
        }
        .navigationTitle("Crear comunidad")
        .task {
            createCommunityViewModel.friends = await createCommunityViewModel.fetchFriends()
            print(createCommunityViewModel.friends)
        }
    }
    
    //MARK: - Seleccionar avatar de la comunidad
    @ViewBuilder
    func SelectAvatarView() -> some View {
        VStack {
            if let selectedImage = selectedImage {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    selectedImage
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .frame(width: 170, height: 170)
                }
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "photo.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.black)
                        .frame(width: 180, height: 180)
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            // Cargar la imagen seleccionada en firestore
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = Image(uiImage: uiImage)
//                    await newAccountViewModel.saveImage(image: uiImage)
//                    
//                    if newAccountViewModel.showImageUploadError {
//                        selectedImage = nil
//                    }
                }
            }
        }
    }
}

#Preview {
    CreateCommunityView()
}
