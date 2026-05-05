//
//  SearchSessionView.swift
//  PicSea
//

import SwiftUI
import Photos

struct SearchSessionView: View {
    @ObservedObject var vm: PhotoLibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query: PhotoSearchQuery
    @State private var promptText: String
    @State private var showFilters = false

    @State private var isSelectionMode = false
    @State private var selectedAssetIDs: Set<String> = []

    @State private var showAlbumPrompt = false
    @State private var albumNameInput = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let parser = PromptParser()

    init(vm: PhotoLibraryViewModel, query: PhotoSearchQuery) {
        self.vm = vm
        _query = State(initialValue: query)
        _promptText = State(initialValue: query.originalText)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    filterSummarySection

                    if showFilters {
                        filterEditor
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                            ForEach(vm.assets, id: \.localIdentifier) { asset in
                                SelectableAssetThumbnail(
                                    asset: asset,
                                    size: 100,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedAssetIDs.contains(asset.localIdentifier)
                                ) {
                                    toggleSelection(for: asset)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                        .padding(.bottom, 140)
                    }
                }

                VStack(spacing: 10) {
                    if !vm.assets.isEmpty {
                        Button {
                            saveTapped()
                        } label: {
                            Text(saveButtonTitle)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal, 40)
                    }

                    searchBarSection
                }
                .padding(.bottom, 8)
            }
            .navigationTitle("PicSea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !vm.assets.isEmpty {
                        Button(selectionButtonTitle) {
                            selectionButtonTapped()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAlbumPrompt) {
            AlbumCreationView(albumName: $albumNameInput) {
                showAlbumPrompt = false
                let finalName = albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "PicSea Results"
                    : albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines)

                let assetsToSave = assetsToSave()

                vm.saveSpecificAssetsToAlbum(assetsToSave, named: finalName) { success, error in
                    alertTitle = success ? "Saved to Album" : "Couldn't Save"
                    alertMessage = success
                        ? "Your selected results were saved in \"\(finalName)\"."
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
        .onAppear {
            applyFilters()
        }
    }

    private var searchBarSection: some View {
        HStack(spacing: 8) {
            TextField("Enter your prompt...", text: $promptText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit {
                    applyPromptAndRefresh()
                }

            Button("Submit") {
                applyPromptAndRefresh()
            }
            .buttonStyle(.borderedProminent)
            .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var filterSummarySection: some View {
        Button {
            showFilters.toggle()
        } label: {
            HStack {
                Text(filterSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: showFilters ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var filterEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Media Type", selection: $query.mediaType) {
                ForEach(MediaType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Include blurry photos", isOn: $query.includeBlurred)
            Toggle("Only duplicate photos", isOn: $query.onlyDuplicates)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    OptionalDateField(date: Binding(
                        get: { query.startDate },
                        set: { query.startDate = $0 }
                    ))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("End Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    OptionalDateField(date: Binding(
                        get: { query.endDate },
                        set: { query.endDate = $0 }
                    ))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !query.concepts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Concepts")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(query.concepts.joined(separator: ", "))
                        .font(.subheadline)
                }
            }

            Button("Apply Filters") {
                applyFilters()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var filterSummaryText: String {
        var parts: [String] = []

        if !query.concepts.isEmpty {
            parts.append(query.concepts.joined(separator: ", "))
        }

        if query.mediaType != .any {
            parts.append(query.mediaType.displayName)
        }

        if let startDate = query.startDate, let endDate = query.endDate {
            parts.append("\(formattedDate(startDate)) - \(formattedDate(endDate))")
        } else if let startDate = query.startDate {
            parts.append("From \(formattedDate(startDate))")
        } else if let endDate = query.endDate {
            parts.append("Until \(formattedDate(endDate))")
        }

        if query.includeBlurred {
            parts.append("Blurry included")
        }

        if query.onlyDuplicates {
            parts.append("Only duplicates")
        }

        return parts.isEmpty ? "More filters" : parts.joined(separator: " • ")
    }

    private var selectionButtonTitle: String {
        if !isSelectionMode {
            return "Select"
        } else if selectedAssetIDs.count == vm.assets.count, !vm.assets.isEmpty {
            return "Deselect All"
        } else {
            return "Select All"
        }
    }

    private var saveButtonTitle: String {
        if isSelectionMode {
            let count = selectedAssetIDs.count
            return count == 0 ? "Save Results" : "Save \(count) Selected"
        } else {
            return "Save Results"
        }
    }

    private func selectionButtonTapped() {
        if !isSelectionMode {
            isSelectionMode = true
            selectedAssetIDs.removeAll()
        } else if selectedAssetIDs.count == vm.assets.count {
            selectedAssetIDs.removeAll()
        } else {
            selectedAssetIDs = Set(vm.assets.map(\.localIdentifier))
        }
    }

    private func toggleSelection(for asset: PHAsset) {
        guard isSelectionMode else { return }

        if selectedAssetIDs.contains(asset.localIdentifier) {
            selectedAssetIDs.remove(asset.localIdentifier)
        } else {
            selectedAssetIDs.insert(asset.localIdentifier)
        }
    }

    private func saveTapped() {
        albumNameInput = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        showAlbumPrompt = true
    }

    private func assetsToSave() -> [PHAsset] {
        if isSelectionMode && !selectedAssetIDs.isEmpty {
            return vm.assets.filter { selectedAssetIDs.contains($0.localIdentifier) }
        } else {
            return vm.assets
        }
    }

    private func applyPromptAndRefresh() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let parsed = parser.parse(trimmed)

        query.originalText = parsed.originalText
        query.concepts = parsed.concepts

        if parsed.mediaType != .any {
            query.mediaType = parsed.mediaType
        }

        if query.startDate == nil {
            query.startDate = parsed.startDate
        }

        if query.endDate == nil {
            query.endDate = parsed.endDate
        }

        if !query.includeBlurred {
            query.includeBlurred = parsed.includeBlurred
        }

        if !query.onlyDuplicates {
            query.onlyDuplicates = parsed.onlyDuplicates
        }

        applyFilters()
    }

    private func applyFilters() {
        selectedAssetIDs.removeAll()

        Task {
            let results = await vm.search(in: vm.allAssets, query: query)
            vm.assets = results
            vm.isFilteredResults = true
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
