//
//  NetworkMonitor.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 2/2/25.
//

import Network

@MainActor
class NetworkMonitor {
    private let monitor = NWPathMonitor()
    
    /// Ofrece un AsyncStream que emite true/false dependiendo de la conexión.
    func connectionStatuses() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            
            // Opcionalmente, usa una cola específica si lo deseas
            let queue = DispatchQueue(label: "NetworkMonitorQueue")
            
            // Cada vez que cambia la conectividad, “yield” un nuevo valor
            monitor.pathUpdateHandler = { path in
                let isConnected = (path.status == .satisfied)
                continuation.yield(isConnected)
            }
            
            // Iniciar el monitor
            monitor.start(queue: queue)
            
            // Si el stream termina (por ejemplo, la vista desaparece), detenemos el monitor
            continuation.onTermination = { @Sendable _ in
                self.monitor.cancel()
            }
        }
    }
}

