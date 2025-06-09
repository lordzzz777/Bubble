//
//  FileCacheActor.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 9/6/25.
//

import Foundation

actor FileCacheActor {
    
    /// Descarga un recurso remoto a Caches/ (si no existe) y devuelve la URL local.
    /// Concurrency-safe gracias al aislamiento del actor.
    func localURL(for url: URL) async throws -> URL {
       
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dest = caches.appendingPathComponent(url.lastPathComponent)
        
        do{
            
        if FileManager.default.fileExists(atPath: dest.path){return dest}
        
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: dest, options: .atomic)
           
        }catch{
            throw error
        }
        
        return dest
    }
}
