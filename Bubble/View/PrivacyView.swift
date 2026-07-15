//
//  PrivacyView.swift
//  Bubble
//
//  Created by Codex on 14/7/26.
//

import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section("Datos de cuenta") {
                Label("Usamos Firebase Auth para identificar tu cuenta.", systemImage: "person.badge.key")
                Label("No guardamos contraseñas en Firestore ni en el dispositivo.", systemImage: "key.slash")
                Label("El nickname y la foto de perfil son visibles para otros usuarios.", systemImage: "person.crop.circle")
            }
            
            Section("Mensajes privados") {
                Label("Los textos privados se cifran antes de guardarse.", systemImage: "lock")
                Label("Imágenes, audios y archivos privados se suben cifrados.", systemImage: "doc.badge.lock")
                Label("Las claves privadas se guardan en el llavero del dispositivo.", systemImage: "lock.iphone")
            }
            
            Section("Mensajes públicos") {
                Label("El chat público no es un espacio privado extremo a extremo.", systemImage: "person.3")
                Label("No compartas información sensible en chats públicos.", systemImage: "exclamationmark.triangle")
            }
            
            Section("Control de cuenta") {
                Label("Puedes eliminar tu cuenta desde Cuenta > Eliminar cuenta.", systemImage: "trash")
                Label("Al eliminarla se borra tu perfil y se desvinculan tus mensajes anteriores.", systemImage: "person.crop.circle.badge.xmark")
            }
            
            Section("Seguridad de comunidad") {
                Label("Puedes reportar mensajes desde el menú de cada mensaje.", systemImage: "flag")
                Label("Puedes bloquear usuarios desde el menú del chat privado.", systemImage: "hand.raised")
            }
            
            Section("Pendiente para producción") {
                Label("Completar la política de privacidad legal en App Store Connect.", systemImage: "doc.text")
                Label("Desplegar reglas de Firestore y Storage antes de publicar.", systemImage: "server.rack")
            }
        }
        .navigationTitle("Privacidad")
    }
}

#Preview {
    NavigationStack {
        PrivacyView()
    }
}
