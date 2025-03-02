//
//  UserProfileView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/3/25.
//

import SwiftUI
import PhotosUI
import FirebaseCore

struct UserProfileView: View {
    @Bindable var userProfileView: NewAccountViewModel = .init()
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var newNickname: String = ""
    
    @State private var nickNameNotExists: Bool = false
    @State private var checkingNickName: Bool = false
    @State private var isEditingNickname: Bool = false
    
    var body: some View {
        NavigationStack{
            VStack(spacing: 20) {
                profileImage() // Llamada funcion del PhotosPicker
                
                // Nickname
                if isEditingNickname {
                    TextField("Nuevo nickname", text: $newNickname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onChange(of: newNickname) {
                            Task {
                                checkingNickName = true // Para mostrar el progress view
                                nickNameNotExists = await userProfileView.checkNickNameNotExists(nickName: newNickname) // Checkea si el nickname no existe en firestore
                                checkingNickName = false
                            }
                        }
                    Button("Guardar") {
                        Task {
                            await userProfileView.updateNicname(newNickname: newNickname)
                            isEditingNickname = false
                        }
                    }.disabled(nickNameNotExists ?  false : true)
                        .buttonStyle(.borderedProminent)
                        .padding()
                } else {
                    Text(userProfileView.user?.nickname ?? "")
                        .font(.title2)
                        .bold()
                }
                
                Spacer()
            }
            .padding()
            .task {
                await userProfileView.loadUserData()
            }
            .alert(userProfileView.errorTitle, isPresented: $userProfileView.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(userProfileView.errorDescription)
            }
            
            .toolbar{
                ToolbarItem(placement: .automatic, content: {
                    Button("Editar") {
                        withAnimation(.easeInOut, {
                            isEditingNickname.toggle()
                        })
                        newNickname = userProfileView.user?.nickname ?? ""

                        
                    }
                })
            }
        }
    }
    
    // Funcion que activa el PhotosPicker y actualiza las imagen de perfil
    @ViewBuilder
    func profileImage() -> some View {
        VStack {
            if let selectedImage = selectedImage {
                PhotosPicker(selection: $selectedItem, photoLibrary: .shared()) {
                    selectedImage
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .frame(width: 170, height: 170)
                }
                
            } else {
                if let imageURL = userProfileView.user?.imgUrl, let url = URL(string: imageURL){
                    PhotosPicker(selection: $selectedItem, label: {
                        AsyncImage(url: url){ images in
                            switch images {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            case .failure(_):
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 120))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    })
                    
                }else{
                    EmptyView()
                }
            }

        }
        .onChange(of: selectedItem) { _, newItem in
            // Cargar la imagen seleccionada en firestore
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = Image(uiImage: uiImage)
                    await userProfileView.saveImage(image: uiImage)
                    
                    if userProfileView.showImageUploadError {
                        selectedImage = nil
                    }
                }
            }
        }
    }
    
}

#Preview {
    UserProfileView()
}
