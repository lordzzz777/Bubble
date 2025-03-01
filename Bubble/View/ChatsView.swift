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
    @Bindable private var chatsViewModel = ChatViewModel()
    @State private var trashUserDefault = LoginViewModel()
    @State private var isMessageDestructive = false
    
    // Esta es la variable que almacenará el valor seleccionado del Picker
    @State private var chatIdSelected: String = ""
    
    var body: some View {
        NavigationStack {
            // Usamos un Picker con un estilo segmentado
            VStack{
                Picker("Visibilidad", selection: $chatsViewModel.selectedVisibility) {
                    ForEach(chatsViewModel.visibilityOptions, id: \.self) { option in
                        Text(option)
                            .tag(option) // Asegúrate de usar .tag para asociar cada Text con su valor
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if $chatsViewModel.chats.isEmpty {
                    Text("No tienes chats aún")
                        .font(.largeTitle.bold())
                        .padding(.bottom, 20)
                    
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                        .font(.system(size: 100))
                    
                    Spacer()
                    
                }else{
                    Text(trashUserDefault.errorMessage)
                  
                    List {
                        ForEach(chatsViewModel.chats, id: \.lastMessageTimestamp) { chat in
                            NavigationLink(destination: {
                                
                            }, label: {
                                VStack(alignment: .leading) {
                                    ListChatRowView(
                                        userID: chatsViewModel.getFriendID(chat.participants),
                                        lastMessage: chat.lastMessage,
                                        timestamp: chat.lastMessageTimestamp
                                    )
                                }
                            })
                            .swipeActions {
                                Button("Borrar", systemImage: "trash.fill") {
                                    chatIdSelected = chat.id
                                    isMessageDestructive = true
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
            .searchable(text: $chatsViewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .always)) {
                ForEach(chatsViewModel.visibilityOptions, id: \.self) { option in
                    Text(option).searchCompletion(option)
                }
            }
            
            .navigationTitle("Chats")
            .task {
                await chatsViewModel.fetchCats()
            }

            // Alerta de Error
            .alert(isPresented: $chatsViewModel.isfetchChatsError) {
                Alert(title: Text(chatsViewModel.errorTitle), message: Text(chatsViewModel.errorDescription), dismissButton: .default(Text("OK"))
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
                            
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fullScreenCover(isPresented: $chatsViewModel.showAddFriendView) {
                AddNewFriendView()
            }
        }
    }

}

#Preview {
    ChatsView()
}
