//
//  ContentView.swift
//  PicSea
//

import SwiftUI
import Photos

struct ContentView: View {
    @StateObject var vm: PhotoLibraryViewModel

    @State private var newName = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    @State private var showAlbumPrompt = false
    @State private var albumNameInput = ""
    @State private var continueFromResults = false

    var body: some View {
        NavigationView {
            Group {
                if !vm.authorized {
                    VStack {
                        Text("PicSea needs access to your photos.")
                            .padding()
                        Button("Grant Access") { vm.loadPhotos() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 12) {

                        // Save button above results
                        if vm.isFilteredResults &&
                           (!newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || continueFromResults) {

                            HStack {
                                Button {
                                    albumNameInput = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    showAlbumPrompt = true
                                } label: {
                                    Label("Save Results to Album", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)

                                Spacer()
                            }
                            .padding(.horizontal)
                        }

                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                                ForEach(vm.assets, id: \.localIdentifier) { asset in
                                    PhotoThumbnail(asset: asset)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("PicSea Library")
            .onAppear { vm.loadPhotos() }

            .safeAreaInset(edge: .bottom) {

                VStack(spacing: 8) {

                    // TOGGLE ABOVE SEARCH BAR
                    if vm.isFilteredResults &&
                        (!newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || continueFromResults) {

                        Toggle("Continue searching from these results", isOn: $continueFromResults)
                            .padding(.horizontal)
                    }

                    // SEARCH BAR
                    HStack(spacing: 8) {
                        TextField("Enter your prompt...", text: $newName)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit { submit() }
                            .onChange(of: newName) { oldValue, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                                if trimmed.isEmpty && !continueFromResults {
                                    vm.resetAssets()
                                    vm.isFilteredResults = false
                                }
                            }

                        Button("Submit") { submit() }
                            .buttonStyle(.borderedProminent)
                            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }

            // Global change handler (always active)
            .onChange(of: continueFromResults) { oldVal, newVal in
                if oldVal == true &&
                   newVal == false &&
                   newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                    print("TEST → Resetting due to toggle OFF with blank prompt")
                    vm.resetAssets()
                    vm.isFilteredResults = false
                }
            }

            .sheet(isPresented: $showAlbumPrompt) {
                AlbumCreationView(albumName: $albumNameInput) {
                    showAlbumPrompt = false
                    let finalName = albumNameInput.isEmpty ? "PicSea Results" : albumNameInput
                    vm.saveResultsToAlbum(named: finalName) { success, error in
                        alertTitle = success ? "Saved to Album" : "Couldn't Save"
                        alertMessage = success
                            ? "Your current results were saved in “\(finalName)”."
                            : (error?.localizedDescription ?? "Unknown error.")
                        showAlert = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func submit() {
        let query = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseAssets = continueFromResults ? vm.assets : vm.allAssets

        if query.isEmpty {
            vm.resetAssets()
            vm.isFilteredResults = false
            print("Search cleared → showing all assets")
            return
        }

        print("Search for: \"\(query)\"")

        Task {
            let results = await vm.search(in: baseAssets, prompt: query)
            vm.assets = results
            vm.isFilteredResults = true
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
            guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return }

            PhotoLibraryManager.requestImage(for: asset) { img in
                if let validImg = img, validImg.size.width > 0, validImg.size.height > 0 {
                    self.image = validImg
                }
            }
        }
    }
}
