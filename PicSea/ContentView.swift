//
//  ContentView.swift
//  PicSea
//

import SwiftUI
import Photos

struct ContentView: View {
    @StateObject var viewModel = PhotoLibraryViewModel()

    var body: some View {
        NavigationView {
            Group {
                if !viewModel.authorized {
                    VStack {
                        Text("PicSea needs access to your photos.")
                            .padding()
                        Button("Grant Access") {
                            viewModel.loadPhotos()
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                            ForEach(viewModel.assets, id: \.localIdentifier) { asset in
                                PhotoThumbnail(asset: asset)
                            }
                        }
                    }
                }
            }
            .navigationTitle("PicSea Library")
            .onAppear { viewModel.loadPhotos() }
        }
    }
}

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
            }
        }
        .onAppear {
            PhotoLibraryManager.requestImage(for: asset) { img in
                self.image = img
            }
        }
    }
}

