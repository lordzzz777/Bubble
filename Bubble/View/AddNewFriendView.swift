//
//  AddNewFriendView.swift
//  Bubble
//
//  Created by Jacob Aguilar on 2/9/25.
//

import SwiftUI

struct AddNewFriendView: View {
    @State private var addNewFriendViewModel: AddNewFriendViewModel = .init()
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(addNewFriendViewModel.matchedUsers, id: \.id) { user in
                MatchedFriendRowView(user: user) {
                    
                }
            }
            .searchable(text: $addNewFriendViewModel.friendNickname, placement: .automatic, prompt: Text("Busca por el nickname de tu amigo"))
            .onChange(of: addNewFriendViewModel.friendNickname) { _, _ in
                Task {
                    await addNewFriendViewModel.searchFriendByNickname(addNewFriendViewModel.friendNickname)
                }
            }
            .navigationTitle("Agregar amigo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "x.circle.fill")
                    }
                }
            }
        }
    }
}

#Preview {
    AddNewFriendView()
}
