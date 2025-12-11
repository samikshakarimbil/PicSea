//
//  AlbumCreationView.swift
//  PicSea
//

import SwiftUI

struct AlbumCreationView: View {
    @Binding var albumName: String
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Album")
                .font(.title2)

            TextField("Album name", text: $albumName)
                .textFieldStyle(.roundedBorder)

            Button("Create") {
                onCreate()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
