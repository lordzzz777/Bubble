//
//  ComponetButtonView.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 27/1/25.
//

import SwiftUI

struct ComponetButtonView: View {
     let titleButtons: String
     let nameIcons: String?
     let isSystemImage: Bool
     let width: CGFloat
     let height: CGFloat
     let color: Color
     let actions: () -> Void
    
    var body: some View {
        Button(action: {
            actions()
        }, label: {
            if let nameIcons = nameIcons {
                if isSystemImage {
                    Image(systemName: nameIcons).font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(titleButtons).font(.title3.bold())
                        .foregroundStyle(.white)
                }else{
                    Image(nameIcons)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    Text(titleButtons).font(.title3.bold())
                        .foregroundStyle(.black)
                }
            }

        })
        .background{
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary, lineWidth: 2)
                .fill(color)
                .frame(width: width, height: height)
                
                
        }.padding()
    }
}

#Preview {
    ComponetButtonView(titleButtons: "Inniciar con ...", nameIcons: "apple.logo",isSystemImage: true, width: 300,height: 50, color: Color.black, actions: {})
}

#Preview {
    WelcomeView()
}
