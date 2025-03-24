//
//  SettingView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 13/2/25.
//

import SwiftUI

struct SettingView: View {
    @State var isShowEditUser: Bool = true
    @State private var isShowAlertWarning = false
    @State private var trashUserDefault = LoginViewModel()
    
    var general: [SettingModel]{
        return[
        .init(titleSetting: "Cuenta", selectedView: AnyView(UserProfileView())),
        .init(titleSetting: "Privacidad", selectedView: AnyView(Text("Mi privacidad"))),
        .init(titleSetting: "Chats", selectedView: AnyView(Text("Mis chats"))),
        .init(titleSetting: "Favoritos", selectedView: AnyView(Text("Mis favoritos")))
     ]
    }
    
    let informationSupport: [SettingModel] = [
        .init(titleSetting: "Terminos de privacidad", selectedView: AnyView(Text("Terminos y condiciones"))),
        .init(titleSetting: "Ayuda", selectedView: AnyView(Text("Te ayudamos"))),
        .init(titleSetting: "Información", selectedView: AnyView(Text("Esto es un quienes somos ...")))
    ]
    
    var body: some View {

        NavigationStack{
            Form{
                Section("General"){
                    List(general) { item in
                        NavigationLink(item.titleSetting, destination: {
                            item.selectedView
                        })
                    }
                }
                
                Section("Informacion y soporte"){
                    List(informationSupport) { item in
                        NavigationLink(item.titleSetting, destination: {
                            item.selectedView
                        })
                    }
                }
                
                Button("Cerra sesión", action: {
                    isShowAlertWarning = true
                }).tint(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle("Configuración")
            
            .alert("Cerrar sesión", isPresented: $isShowAlertWarning) {
                Button("Cancelar", role: .cancel) {}
                Button("Confirmar", role: .destructive) {
                    trashUserDefault.logoutUser()
                }
            } message: {
                Text("La sesión actual se cerrará y deberás volver a identificarte")
            }
        }
    }
}

#Preview {
    SettingView()
}
