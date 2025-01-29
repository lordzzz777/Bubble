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
    @State private var nickname: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                //MARK: - Seleccionar avatar
                SelectAvatarView()
                
                TextField("Nickname", text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.top)
                
                
                Spacer()
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
                    .frame(width: 170, height: 170)
            } else {
                // PhotosPicker nativo de SwiftUI
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.black)
                        .frame(width: 180, height: 180)
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
