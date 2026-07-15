//
//  BubbleAppCheckProviderFactory.swift
//  Bubble
//
//  Created by Codex on 14/7/26.
//

import FirebaseAppCheck
import FirebaseCore

final class BubbleAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProviderFactory().createProvider(with: app)
    }
}
