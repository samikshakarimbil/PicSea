//
//  ContentView.swift
//  PicSea
//

import SwiftUI
import Photos

struct ContentView: View {
    @StateObject var viewModel = PhotoLibraryViewModel()

    @State private var newName = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

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
                        .buttonStyle(.borderedProminent)
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

            // Bottom input bar
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    TextField("New folder name…", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit { submit() }

                    Button("Submit") { submit() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom) // keep bar visible when keyboard is up
    }

    private func submit() {
        let query = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let results = viewModel.search(prompt: query)
        viewModel.assets = results
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func handleResult(kind: String, name: String, success: Bool, error: Error?) {
        if success {
            alertTitle = "\(kind) Created"
            alertMessage = "\"\(name)\" was created in Photos."
            newName = ""
        } else {
            alertTitle = "Couldn't Create \(kind)"
            alertMessage = error?.localizedDescription ?? "Unknown error."
        }
        showAlert = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
