//
//  NewAccountView.swift
//  Bubble
//
//  Created by Jacob on 28-01-25.
//

import SwiftUI
import PhotosUI
import FirebaseCore


struct NewAccountView: View {
    @State var newAccountViewModel: NewAccountViewModel = .init()
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var nickname: String = ""
    @State private var nickNameNotExists: Bool = false
    @State private var checkingNickName: Bool = false
    
    
    @AppStorage("LoginFlowState") private var loginFlowState: UserLoginState = .loggedIn
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                
                // Llamada funcion del PhotosPicker
                newAccountViewModel.selectAvatarView($selectedItem, $selectedImage)
                
                VStack(alignment: .leading, spacing: 2) {
                    ZStack(alignment: .trailing) {
                        TextField("Nickname", text: $nickname)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: nickname) {
                                Task {
                                    checkingNickName = true // Para mostrar el progress view
                                    nickNameNotExists = await newAccountViewModel.checkNickNameNotExists(nickName: nickname) // Checkea si el nickname no existe en firestore
                                    checkingNickName = false
                                }
                            }
                            .overlay {
                                if checkingNickName {
                                    HStack {
                                        Spacer()
                                        
                                        ProgressView()
                                            .scaleEffect(1.2)
                                    }
                                    .padding(.trailing, 4)
                                }
                            }
                    }
                    
                    if !nickNameNotExists && !nickname.isEmpty && !checkingNickName {
                        Label {
                            Text("Este nickname ya está en uso")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Spacer()
            }
            .navigationTitle("Nueva cuenta")
            .toolbar {
                // Habilita el botón solo si el nickname no está vacío y si el nickname no existe en la base de datos
                if !nickname.isEmpty && nickNameNotExists {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task {
                                await newAccountViewModel.createUser(
                                    user: UserModel(
                                        id: "",
                                        nickname: nickname,
                                        imgUrl: "",
                                        lastConnectionTimeStamp: Timestamp.init(),
                                        isOnline: true, chats: [],
                                        friends: [],
                                        isDeleted: false)
                                )
                                
                                // Una vez registrado el nickname, cambiar el estado a `.hasNickname`
                                loginFlowState = .loggedIn
                            }
                        } label: {
                            Text("Finalizar")
                        }
                    }
                }
            }
            .alert(isPresented: $newAccountViewModel.showError) {
                Alert(title: Text(newAccountViewModel.errorTitle), message: Text(newAccountViewModel.errorDescription), dismissButton: .default(Text("Aceptar")))
            }
        }
    }
}

#Preview {
    NewAccountView()
}
