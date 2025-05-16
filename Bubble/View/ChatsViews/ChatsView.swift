//
//  HomeView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 30/1/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseCore
import FirebaseAuth

struct ChatsView: View {
    
    @State private var chatsViewModel = PrivateChatViewModel()
    @State private var trashUserDefault = LoginViewModel()
    @State private var userViewModel = UserViewModel()
    @State private var createCommunityViewModel = CreateCommunityViewModel()
    @State private var isMessageDestructive = false
    @State private var isShowingToggle = false
    
    // Esta es la variable que almacenará el valor seleccionado del Picker
    @State private var chatIdSelected: String = ""
    
    var body: some View {
        NavigationStack {
            
            
            
            // Usamos un Picker con un estilo segmentado
            VStack{
                
                if $chatsViewModel.chats.isEmpty {
                    
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                        .font(.system(size: 100))
                    
                    Text("No tienes chats aún")
                        .font(.largeTitle.bold())
                        .padding(.bottom, 20)
                    
                }else{

                    List {
                        ForEach(chatsViewModel.filteredChats, id: \.id) { chat in
                            ListChatRowView(chat: chat)
                                .swipeActions {
                                    Button("Borrar", systemImage: "trash.fill") {
                                        chatIdSelected = chat.id
                                        isMessageDestructive = true
                                    }
                                    .tint(.red)
                                }
                        }
                       //.listStyle(PlainListStyle())
                        .listStyle(.plain)
                        
                    }.overlay(content: {
                        if isShowingToggle{
                            VStack(alignment: .leading, spacing: 8) {
                                if let user = userViewModel.user {
                                    Toggle(isOn: Binding<Bool>(
                                        get: { user.isOnline },
                                        set: { newValue in
                                            Task {
                                                await userViewModel.updateUserStatus(online: newValue)
                                                await userViewModel.loadUser()
                                            }
                                        }
                                    )) {
                                        Text("Estado:  \(user.isOnline ? "🟢 Conectado" : "⚪️ Desconectado")")
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .green))
                                    .padding(.horizontal)
                                }
                                
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)))
                            .padding(.horizontal)
                            .offset(y: 250)
                        }
                    })
                }
            }
            .searchable(text: $chatsViewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .always)) {
            }
            .navigationTitle("Chats")
            .task {
                await userViewModel.loadUser()
                await chatsViewModel.fetchChats()
            }
            .onChange(of: userViewModel.user?.isOnline) { _, _ in
                Task { await userViewModel.loadUser() }
            }

            // Alerta de Error
            .alert(isPresented: $chatsViewModel.showError) {
                Alert(title: Text(chatsViewModel.errorTitle), message: Text(chatsViewModel.errorMessage), dismissButton: .default(Text("OK"))
                )
            }
            
            // Alerta de advertencia antes de eliminar el chat
            .alert("⚠️ Eliminar Chat",
                   isPresented: $isMessageDestructive,
                   actions: {
                Button("Eliminar") {
                    chatsViewModel.deleteChat(chatID: chatIdSelected)
                }
                
                Button("Cancelar", role: .cancel) {}
            }, message: {
                Text("Si confirmas, se eliminará el Chat y la conversación de forma permanente y no podrás recuperarla. ¿Deseas continuar?")
            })
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Agregar amigo", systemImage: "person.fill.badge.plus") {
                            chatsViewModel.showAddFriendView.toggle()
                        }
                        
                        Button("Crear comunidad", systemImage: "person.2.badge.plus.fill") {
                            createCommunityViewModel.showCreateNewCommunity.toggle()
                        }
                        
                        Button("Status de conexion", systemImage: isShowingToggle ? "eye" : "eye.slash") {
                            withAnimation(.easeInOut){
                                isShowingToggle.toggle()
                            }
                        }
                        
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $chatsViewModel.showAddFriendView) {
                AddNewFriendView()
            }
            .sheet(isPresented: $createCommunityViewModel.showCreateNewCommunity, onDismiss: {
                Task {
                    await createCommunityViewModel.removeImageFromFirebaseStorage(imageURL: createCommunityViewModel.community.imgUrl)
                }
            }) {
                CreateCommunityView(createCommunityViewModel: createCommunityViewModel)
            }
        }
    }
    
}

#Preview {
    ChatsView()
}
