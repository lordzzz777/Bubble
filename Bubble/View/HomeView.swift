//
//  HomeView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 30/1/25.
//

import SwiftUI

struct HomeView: View {
    // Esta es la variable que almacenará el valor seleccionado del Picker
    @State private var selectedVisibility = "privado"
    @State private var searchText = ""
    
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
            Picker("Visibilidad", selection: $selectedVisibility) {
                ForEach(visibilityOptions, id: \.self) { option in
                    Text(option).tag(option) // Asegúrate de usar .tag para asociar cada Text con su valor
                }
            }
            .pickerStyle(.segmented)
                .padding()
                List{
                    
                    ForEach(dataList){ item in
                        NavigationLink(destination: {
                            
                        }, label: {
                            HStack{
                                Circle().frame(width: 50, height: 50, alignment: .center)
                                    .overlay(content: {
                                        Image(item.nameImage).resizable()
                                            .scaledToFill()
                                            
                                    }).clipShape(Circle())
                                Text(item.nameAlias)
                                Spacer()
                                Text(item.dataTimer)
                            } .swipeActions(content: {
                                Button("borrar", systemImage: "trash.fill", role: .destructive, action: {
                                    // ... Lógica eliminar
                                })
                            })
                            
                        })

 
                        
                    }
                    
                }
                .navigationTitle("Chat")
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always)) {
                    ForEach(visibilityOptions, id: \.self) { option in
                        Text(option).searchCompletion(option)
                    }
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
