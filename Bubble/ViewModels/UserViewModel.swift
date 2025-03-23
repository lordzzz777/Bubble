//
//  UserViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 23/3/25.
//

import Foundation

@Observable @MainActor
class UserViewModel {
    
    private let firestoreService = FirestoreService()
    private let networkMonitor = NetworkMonitor()
    private var cancellabeTask: Task<Void,Never>?
    
    var isConnected: Bool = false
    
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
    
    func updateUserStatus(online: Bool) async {
        do{
           try await firestoreService.updateUserStatus(isOnline: online)
        }catch{
            print("No se pudo actualizar el estado: \(error)")
        }
    }
    
    func storeLastSeen() async {
        do {
            try await firestoreService.storeLastSeen()
        } catch {
            print("No se pudo guardar la última conexión: \(error)")
        }
    }
    
}
