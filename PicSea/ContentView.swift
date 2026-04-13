//
//  ContentView.swift
//  PicSea
//

import SwiftUI
import Photos

struct ContentView: View {
    @StateObject var vm: PhotoLibraryViewModel

    @State private var promptText = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    @State private var showAlbumPrompt = false
    @State private var albumNameInput = ""
    @State private var continueFromResults = false
    
    @State private var parsedQuery = PhotoSearchQuery()
    @State private var showFiltersScreen = false

    private let parser = PromptParser()

    var body: some View {
        NavigationStack {
            Group {
                if !vm.authorized {
                    VStack(spacing: 16) {
                        Text("PicSea needs access to your photos.")
                        Button("Grant Access") {
                            vm.loadPhotos()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        if vm.isFilteredResults &&
                            (!promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || continueFromResults) {
                            HStack {
                                Button {
                                    albumNameInput = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
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
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                                ForEach(vm.assets, id: \.localIdentifier) { asset in
                                    AssetThumbnail(asset: asset, size: 100)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .navigationTitle("PicSea Library")
            .onAppear {
                vm.loadPhotos()
            }
            .fullScreenCover(isPresented: $showFiltersScreen) {
                SearchSessionView(vm: vm, query: parsedQuery)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if vm.isFilteredResults &&
                        (!promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || continueFromResults) {
                        Toggle("Continue searching from these results", isOn: $continueFromResults)
                            .padding(.horizontal)
                    }

                    HStack(spacing: 8) {
                        TextField("Enter your prompt...", text: $promptText)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit {
                                submit()
                            }
                            .onChange(of: promptText) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                                if trimmed.isEmpty && !continueFromResults {
                                    vm.resetAssets()
                                }
                            }

                        Button("Submit") {
                            submit()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .onChange(of: continueFromResults) { oldValue, newValue in
                if oldValue == true &&
                    newValue == false &&
                    promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    vm.resetAssets()
                }
            }
            .sheet(isPresented: $showAlbumPrompt) {
                AlbumCreationView(albumName: $albumNameInput) {
                    showAlbumPrompt = false
                    let finalName = albumNameInput.isEmpty ? "PicSea Results" : albumNameInput

                    vm.saveResultsToAlbum(named: finalName) { success, error in
                        alertTitle = success ? "Saved to Album" : "Couldn't Save"
                        alertMessage = success
                            ? "Your current results were saved in \"\(finalName)\"."
                            : (error?.localizedDescription ?? "Unknown error.")
                        showAlert = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func submit() {
        let query = promptText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            vm.resetAssets()
            return
        }

        parsedQuery = parser.parse(query)
        showFiltersScreen = true
    }
}
