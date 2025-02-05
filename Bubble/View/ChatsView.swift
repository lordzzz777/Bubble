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
    
    // Esta es la variable que almacenará el valor seleccionado del Picker
    @State private var selectedVisibility = "privado"
    @State private var searchText = ""
    @State private var isWiffi = false
    @State private var isMessageDestructive = false // activa alerta de eliminacion de chats
    @State private var selectedId = ""
    // Esta es la lista de opciones para el Picker
    private let visibilityOptions = ["privado", "Publico"]
    
    var filteredData: [ModelListMock] {
        if searchText.isEmpty {
            return dataList
        } else {
            return dataList.filter { $0.nameAlias.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        NavigationStack{
            // Usamos un Picker con un estilo segmentado
            VStack{
                Picker("Visibilidad", selection: $selectedVisibility) {
                    ForEach(visibilityOptions, id: \.self) { option in
                        Text(option).tag(option) // Asegúrate de usar .tag para asociar cada Text con su valor
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if $viewModel.chats.isEmpty{
                    Text("No tienes chats aún").font(.largeTitle.bold())
                        .padding(.bottom, 20)
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                        .font(.system(size: 100))
                    Spacer()
                    
                }else{
                    
                    List{
                        ForEach(viewModel.chats, id:\.lastMessageTimestamp){ chat in
                            
                            NavigationLink(destination: {
                                
                            }, label: {
                                VStack(alignment: .leading){
                                    ListChatRowView(userID:viewModel.getFriendID(chat.participants), lastMessage: chat.lastMessage, timestamp: chat.lastMessageTimestamp)
                                }
                            })
                            .swipeActions(content: {
                                Button("borrar", systemImage: "trash.fill", action: {
                                    selectedId = chat.id
                                    isMessageDestructive = true
                                }).tint(.red )
                            })
                            .alert("⚠️ Eliminar Chat",
                                   isPresented: $isMessageDestructive,
                                   actions: {
                                Button("Eliminar") {
                                    Task { @MainActor in
                                        await viewModel.deleteChat(id: chat.id)
                                    }
                                    
                                }
                                Button("Cancelar", role: .cancel) {
                                    // Acción para cancelar
                                }
                            },
                                   message: {
                                Text("Si confirmas, se eliminará el Chat y la conversación de forma permanente y no podrás recuperarla. ¿Deseas continuar?")
                            })
                        }
                        
                    }
                    
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always)) {
                ForEach(visibilityOptions, id: \.self) { option in
                    Text(option).searchCompletion(option)
                }
            }
            .navigationTitle("Chats")
            .onAppear {
                viewModel.fetchChats()
            }
            .alert(isPresented: $viewModel.isfetchChatsError) {
                Alert(title: 
                        Text(viewModel.errorTitle),
                      message: Text(viewModel.errorDescription),
                      dismissButton: .default(Text("OK"))
                )
            }

            
            .toolbar(content: {
                Button(action: {
                    // ... Logica
                }, label: {
                    Image(systemName: "plus")
                })
            })
        }
    }
    
}

#Preview {
    ChatsView()
}
