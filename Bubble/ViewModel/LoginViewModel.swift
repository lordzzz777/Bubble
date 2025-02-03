//
//  LoginViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 28/1/25.
//

import Foundation
import SwiftUI
import Observation


@Observable @MainActor
class LoginViewModel {
    private let googleService = GoogleService()
    
    var showError: Bool = false
    var errorMessage: String = ""
    
    func signInWithGoogle(completion: @escaping(Bool) -> Void) {
        googleService.authenticate { result in
            switch result {
            case .success(let success):
                completion(success ? true : false)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.showError = true
                completion(false)
            }
        }
    }
}
