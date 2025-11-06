//
//  PhotoLibraryScreen.swift
//  PicSea
//
//  Created by Samiksha Karimbil on 11/5/25.
//


import SwiftUI
import Photos

struct PhotoLibraryScreen: View {
    @StateObject var vm = PhotoLibraryViewModel()

    @State private var newName = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 1)]

    var body: some View {
        NavigationView {
            Group {
                if vm.authorized {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 1) {
                            ForEach(vm.assets, id: \.localIdentifier) { asset in
                                AssetThumbnail(asset: asset, size: 100)
                            }
                        }
                    }
                    .navigationTitle("PicSea")
                } else {
                    VStack(spacing: 16) {
                        Text("Photos access is needed to show your library.")
                            .multilineTextAlignment(.center)
                        Button("Allow Access") {
                            vm.loadPhotos()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .navigationTitle("PicSea")
                }
            }
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
    }

    private func submit() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        // CREATE FOLDER:
        vm.createFolder(named: name) { success, error in
            handleResult(kind: "Folder", name: name, success: success, error: error)
        }

        // If you want an ALBUM instead:
        // vm.createAlbum(named: name) { success, error in
        //     handleResult(kind: "Album", name: name, success: success, error: error)
        // }
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
