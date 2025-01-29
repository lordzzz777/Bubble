//
//  NewAccountView.swift
//  Bubble
//
//  Created by Jacob on 28-01-25.
//

import SwiftUI
import PhotosUI

struct NewAccountView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                //MARK: - Seleccionar avatar
                SelectAvatarView()
            }
            .navigationTitle("Nueva cuenta")
        }
    }
    
    @ViewBuilder
    func SelectAvatarView() -> some View {
        VStack {
            if let selectedImage = selectedImage {
                selectedImage
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .frame(width: 150, height: 150)
            } else {
                // PhotosPicker nativo de SwiftUI
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .foregroundColor(.blue)
                }
                .onChange(of: selectedItem, { _, newItem in
                    // Cargar la imagen seleccionada
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = Image(uiImage: uiImage)
                        }
                    }
                })
            }
        }
    }
}

#Preview {
    NewAccountView()
}
