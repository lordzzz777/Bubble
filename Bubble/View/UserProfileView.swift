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
    
    @State private var trashUserDefault = LoginViewModel()

    
    @AppStorage("LoginFlowState") private var loginFlowState: UserLoginState = .loggedIn
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var newNickname: String = ""
    
    @State private var nickNameNotExists: Bool = false
    @State private var checkingNickName: Bool = false
    @State private var isEditingNickname: Bool = false
    @State private var isShowDeleteAlert = false
    
    var body: some View {
        NavigationStack{
            VStack(spacing: 20) {
               // Llamada funcion del PhotosPicker
                userProfileView.profileImage($selectedItem, $selectedImage)
                
                /// Muestra el textFild en caso que el usuario quisiera editar trar pulsar el botón de Editar
                /// situado en la barra de navegación
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
                    
                    /// Verifica si el nickname elejido esta en uso o no ...
                    if !nickNameNotExists && newNickname != userProfileView.user?.nickname ?? ""  && !checkingNickName {
                        
                        
                        Label {
                            Text("Este nickname ya está en uso").bold()
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(.red)
                    }
                    Button("Guardar") {
                        Task {
                            await userProfileView.updateNicname(newNickname: newNickname)
                            isEditingNickname = false
                            await userProfileView.showTemporaryAlert(title: "Nickname", message: "Se ha actualizado con éxito")
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
                Button(role: .destructive,action: {
                    isShowDeleteAlert = true
                }, label: {
                    Text("Eliminar cuenta")
                }).buttonStyle(.borderedProminent)
               
            }.padding()
            
                .task {
                    await userProfileView.loadUserData()
                }
            
                ///Alerta que informa al usuario de un error
                .alert(userProfileView.errorTitle, isPresented: $userProfileView.showError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(userProfileView.errorDescription)
                }
            
                ///Alerta que informa al usuario que tanto la foto de perfil como el nickname, se han editado con exito
                .alert(userProfileView.temporaryTitleAlert, isPresented: $userProfileView.isShowTemporaryAlert){
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(userProfileView.temporaryMessagesAlert)
                }
            
                .alert("¿Estás seguro?", isPresented: $isShowDeleteAlert) {
                    
                    Button("Cancelar", role: .cancel) { }
                    Button("Eliminar", role: .destructive) {
                        // Logica para eliminar cuenta
                        Task{
                            await userProfileView.deleteUserAccount()
                            trashUserDefault.logoutUser()
                            loginFlowState = .loggedOut
                        }
                    }
                    
                } message: {
                    Text("Si eliminas tu cuenta, ya no aparecerás en los chats ni en la lista de amigos. Tus datos se ocultarán, pero podrás recuperar tu cuenta iniciando sesión de nuevo.")
                }
            
                /// Zona de barra de navegación
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
}

#Preview {
    UserProfileView()
}
