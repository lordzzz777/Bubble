//
//  HomeView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 30/1/25.
//

import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @State var viewModel = ChatViewModel()

    // Esta es la variable que almacenará el valor seleccionado del Picker
    @State private var selectedVisibility = "privado"
    @State private var searchText = ""
    @State private var isWiffi = false
    
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
                        ForEach(viewModel.chats, id:\.lastMessageTimestamp.timeIntervalSince1970){ chat in
                            NavigationLink(destination: {
                                
                            }, label: {
                                VStack(alignment: .leading){
                                    //Text("Participantes: \(chat.participants.joined(separator: ", "))")
                                    Text("Nº de Participantes: \(chat.participants.count)")
                                        .font(.headline)
                                    Text("Último mensaje: \(chat.lastMessageTimestamp.formatted(date: .numeric, time: .shortened))")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                } .swipeActions(content: {
                                    Button("borrar", systemImage: "trash.fill", role: .destructive, action: {
                                        // ... Lógica eliminar
                                    })
                                })
                                
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
            .navigationTitle("Chat")
            .task {
                print("📡 Cargando chats...")
                await viewModel.loadChats()
            }
            .alert(isPresented: $viewModel.isMessageError) {
                Alert(title: 
                        Text("Error al cargar los chats"),
                      message: Text("Puede intentar nuevamente."),
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
    HomeView()
}
