//
//  ContentView.swift
//  PicSea
//

import SwiftUI
import Photos

struct ContentView: View {
    @StateObject var vm = PhotoLibraryViewModel()

    @State private var newName = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Group {
                if !vm.authorized {
                    VStack {
                        Text("PicSea needs access to your photos.")
                            .padding()
                        Button("Grant Access") {
                            vm.loadPhotos()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                            ForEach(vm.assets, id: \.localIdentifier) { asset in
                                PhotoThumbnail(asset: asset)
                            }
                        }
                    }
                }
            }
            .navigationTitle("PicSea Library")
            .onAppear { vm.loadPhotos() }

            // Bottom input bar
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    TextField("Enter your prompt...", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit { submit() }
                        .onChange(of: newName) { val in
                            if val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                vm.fetchPhotos()
                            }
                        }

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
        if query.isEmpty {
            // Empty query = show full gallery again
            vm.fetchPhotos()                // repopulates from the photo library
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        let results = vm.search(prompt: query)
        vm.assets = results
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
