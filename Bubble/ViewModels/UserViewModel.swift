//
//  UserViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 23/3/25.
//

import Foundation

@Observable @MainActor
final class UserViewModel {
    
    private let firestoreService = FirestoreService()
    private let networkMonitor = NetworkMonitor()
    private var cancellabeTask: Task<Void,Never>?
    
    
    var user: UserModel?
    var isConnected: Bool = false
    
    // MARK: - Conexión / presencia
    
    /// Escucha cambios de red y sincroniza `isOnline` en Firestore.
    func startMonitoringUserStatus() {
        cancellabeTask?.cancel()
        
        cancellabeTask = Task {
            for await sttus in networkMonitor.connectionStatuses(){
                isConnected = sttus
                
                await updateUserStatus(online: sttus)
                
                if !sttus{
                    await storeLastSeen()
                }
            }
        }
    }
    
    /// Sube el flag de presencia `isOnline` al documento del usuario.
    func updateUserStatus(online: Bool) async {
        do{
           try await firestoreService.updateUserStatus(isOnline: online)
            user?.isOnline = online
            AppLogger.debug("Estado de conexión actualizado.")
        }catch{
            AppLogger.error("No se pudo actualizar el estado del usuario.")
        }
    }
        
    /// Registra `lastConnectionTimestamp` cuando se pierde conexión.
    func storeLastSeen() async {
        do {
            try await firestoreService.storeLastSeen()
        } catch {
            AppLogger.error("No se pudo guardar la última conexión.")
        }
    }
    
    /// Descarga los datos del usuario autenticado y los guarda en `user`.
    func loadUser() async {
        do {
            self.user = try await firestoreService.getUserData()
        } catch {
            AppLogger.error("Error cargando usuario.")
        }
    }
}
