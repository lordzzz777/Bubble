//
//  HomeView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 30/1/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseCore

struct ChatsView: View {
    @Bindable var viewModel = ChatViewModel()

    @State private var chatIdSelected: String = ""
    
    var body: some View {
        NavigationStack {
            // Usamos un Picker con un estilo segmentado
            VStack{
                Picker("Visibilidad", selection: $viewModel.selectedVisibility) {
                    ForEach(viewModel.visibilityOptions, id: \.self) { option in
                        Text(option)
                            .tag(option) // Asegúrate de usar .tag para asociar cada Text con su valor
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if $viewModel.chats.isEmpty {
                    Text("No tienes chats aún")
                        .font(.largeTitle.bold())
                        .padding(.bottom, 20)
                    
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                        .font(.system(size: 100))
                    
                    Spacer()
                } else {
                    
                    List {
                        ForEach(viewModel.chats, id:\.lastMessageTimestamp) { chat in
                            NavigationLink(destination: {
                                
                            }, label: {
                                VStack(alignment: .leading) {
                                    ListChatRowView(userID:viewModel.getFriendID(chat.participants), lastMessage: chat.lastMessage, timestamp: chat.lastMessageTimestamp)

                                }
                            })
                            .swipeActions(content: {
                                Button("borrar", systemImage: "trash.fill", action: {
                                    if let chatID = chat.id {
                                        chatIdSelected = chatID
                                    }
                                    
                                    viewModel.isMessageDestructive = true
                                    
                                })
                                
                                .tint(.red )
                            })

                        }
                        
                    }
                    
                }
            }
            .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .always)) {
                ForEach(viewModel.visibilityOptions, id: \.self) { option in
                    Text(option).searchCompletion(option)
                }
            }
            .navigationTitle("Chats")
            .task {
                await viewModel.fetchCats()
            }
            // Alerta de Error
            .alert(isPresented: $viewModel.isfetchChatsError) {
                Alert(title: Text(viewModel.errorTitle), message: Text(viewModel.errorDescription), dismissButton: .default(Text("OK"))
                )
            }
            // Alerta de corfimación
            .alert(isPresented: $viewModel.isSuccessMessas) {
                Alert(title: Text(viewModel.successMessasTitle), message: Text(viewModel.successMessasDescription), dismissButton: .default(Text("OK")))
            }
            // Alerta de advertencia antes de eliminar el chat
            .alert("⚠️ Eliminar Chat", isPresented: $viewModel.isMessageDestructive, actions: {
                Button("Eliminar") {
                    viewModel.deleteChat(chatID: chatIdSelected)
                }
                
                Button("Cancelar", role: .cancel) {}
            }, message: {
                Text("Si confirmas, se eliminará el Chat y la conversación de forma permanente y no podrás recuperarla. ¿Deseas continuar?")
            })
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Agregar amigo", systemImage: "person.fill.badge.plus") {
                            
                        }
                        
                        Button("Crear comunidad", systemImage: "person.2.badge.plus.fill") {
                            
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

}

#Preview {
    ChatsView()
}
