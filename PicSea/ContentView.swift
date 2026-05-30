//
//  ContentView.swift
//  PicSea
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject var vm: PhotoLibraryViewModel
    @AppStorage("duplicateSimilaritySensitivity") private var duplicateSensitivityRawValue = DuplicateSimilaritySensitivity.medium.rawValue

    @State private var promptText = ""
    @State private var query = PhotoSearchQuery()
    @State private var selectedQuickAction: PhotoQuickAction?
    @State private var isShowingResults = false
    @State private var showFilters = false
    @State private var isSelectionMode = false
    @State private var selectedAssetIDs: Set<String> = []

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    @State private var showAlbumPrompt = false
    @State private var albumNameInput = ""

    private let parser = PromptParser()

    var body: some View {
        NavigationStack {
            Group {
                if !vm.authorized {
                    authorizationView
                } else {
                    VStack(spacing: 0) {
                        if isShowingResults {
                            filterSummarySection

                            if showFilters {
                                filterEditor
                                    .padding(.horizontal)
                                    .padding(.bottom, 10)
                            }
                        }

                        if visibleAssetIDs.isEmpty {
                            ContentUnavailableView(
                                isShowingResults ? "No Matches" : "No Photos",
                                systemImage: "photo.on.rectangle",
                                description: Text(isShowingResults ? "Try relaxing the filters." : "Grant access to more photos to build the preview.")
                            )
                        } else {
                            PhotoAssetGrid(
                                assetIDs: visibleAssetIDs,
                                isSelectionMode: isSelectionMode,
                                selectedAssetIDs: selectedAssetIDs
                            ) { assetID in
                                toggleSelection(for: assetID)
                            } onInteractionChanged: { isActive in
                                vm.setUserInteractionActive(isActive)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isShowingResults ? "Results" : "PicSea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isShowingResults {
                        Button {
                            returnHome()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !isShowingResults {
                        settingsMenu
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isShowingResults && !vm.assetIDs.isEmpty {
                        Button(selectionButtonTitle) {
                            selectionButtonTapped()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isShowingResults && !vm.assetIDs.isEmpty {
                        Button {
                            albumNameInput = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
                            showAlbumPrompt = true
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                    }
                }
            }
            .onAppear {
                vm.setDuplicateSensitivity(duplicateSensitivity)
                vm.loadPhotos()
            }
            .onChange(of: duplicateSensitivityRawValue) { _, _ in
                vm.setDuplicateSensitivity(duplicateSensitivity)
            }
            .safeAreaInset(edge: .bottom) {
                bottomControls
            }
            .sheet(isPresented: $showAlbumPrompt) {
                AlbumCreationView(albumName: $albumNameInput) {
                    showAlbumPrompt = false
                    let finalName = albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "PicSea Results"
                        : albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines)

                    vm.saveSpecificAssetIDsToAlbum(assetIDsToSave, named: finalName) { success, error in
                        alertTitle = success ? "Saved to Album" : "Couldn't Save"
                        alertMessage = success
                            ? "Your current results were saved in \"\(finalName)\"."
                            : (error?.localizedDescription ?? "Unknown error.")
                        showAlert = true
#if !targetEnvironment(simulator)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
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

    private var visibleAssetIDs: [String] {
        isShowingResults ? vm.assetIDs : vm.allAssetIDs
    }

    private var authorizationView: some View {
        VStack(spacing: 16) {
            Text("PicSea needs access to your photos.")

            Button("Grant Access") {
                vm.loadPhotos()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var settingsMenu: some View {
        Menu {
            Picker("Duplicate Similarity", selection: duplicateSensitivityBinding) {
                ForEach(DuplicateSimilaritySensitivity.allCases) { sensitivity in
                    Text(sensitivity.displayName).tag(sensitivity)
                }
            }
        } label: {
            Image(systemName: "gearshape")
        }
    }

    private var duplicateSensitivity: DuplicateSimilaritySensitivity {
        DuplicateSimilaritySensitivity(rawValue: duplicateSensitivityRawValue) ?? .medium
    }

    private var duplicateSensitivityBinding: Binding<DuplicateSimilaritySensitivity> {
        Binding {
            duplicateSensitivity
        } set: { newValue in
            duplicateSensitivityRawValue = newValue.rawValue
            vm.setDuplicateSensitivity(newValue)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            if !isShowingResults {
                quickActionChips
            }

            if vm.isIndexing, !vm.indexingStatusText.isEmpty {
                Text(vm.indexingStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            searchBar
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var quickActionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PhotoQuickAction.allCases) { action in
                    Button {
                        select(action: action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedQuickAction == action ? .accentColor : .secondary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Search photos...", text: $promptText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    submitSearch()
                }

            Button {
                submitSearch()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedQuickAction == nil)
        }
        .padding(.horizontal)
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
            .clipShape(RoundedRectangle(cornerRadius: 8))
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

            HStack {
                Text("Include duplicate photos")

                Spacer()

                Picker("Include duplicate photos", selection: $query.duplicateFilter) {
                    ForEach(DuplicateFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }

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

            Button {
                applyCurrentQuery()
            } label: {
                Label("Apply Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
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

        if query.onlyBlurry {
            parts.append("Blurry only")
        } else if query.includeBlurred {
            parts.append("Blurry included")
        }

        switch query.duplicateFilter {
        case .include:
            parts.append("Duplicates included")
        case .exclude:
            parts.append("Duplicates hidden")
        case .onlyDuplicates:
            parts.append("Only duplicates")
        }

        return parts.isEmpty ? "More filters" : parts.joined(separator: " • ")
    }

    private var selectionButtonTitle: String {
        if !isSelectionMode {
            return "Select"
        } else if selectedAssetIDs.count == vm.assetIDs.count {
            return "Unselect All"
        } else {
            return "Select All"
        }
    }

    private var assetIDsToSave: [String] {
        if isSelectionMode && !selectedAssetIDs.isEmpty {
            return vm.assetIDs.filter { selectedAssetIDs.contains($0) }
        } else {
            return vm.assetIDs
        }
    }

    private func submitSearch() {
        guard selectedQuickAction != nil || !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        query = queryForSearch()
        applyCurrentQuery()
    }

    private func select(action: PhotoQuickAction) {
        selectedQuickAction = action
        promptText = action.title
        query = query(for: action)
        applyCurrentQuery()
    }

    private func query(for action: PhotoQuickAction) -> PhotoSearchQuery {
        var actionQuery = PhotoSearchQuery()

        switch action {
        case .duplicates:
            actionQuery.duplicateFilter = .onlyDuplicates
        case .blurry:
            actionQuery.onlyBlurry = true
            actionQuery.duplicateFilter = .include
        case .screenshots:
            actionQuery.mediaType = .screenshot
            actionQuery.duplicateFilter = .include
        case .selfies:
            actionQuery.mediaType = .selfie
            actionQuery.duplicateFilter = .include
        }

        return actionQuery
    }

    private func queryForSearch() -> PhotoSearchQuery {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        var nextQuery = selectedQuickAction.map(query(for:)) ?? PhotoSearchQuery()

        guard !trimmed.isEmpty else {
            return nextQuery
        }

        let parsed = parser.parse(trimmed)
        nextQuery.originalText = parsed.originalText
        nextQuery.normalizedText = parsed.normalizedText
        nextQuery.searchTokens = parsed.searchTokens
        nextQuery.concepts = parsed.concepts

        if parsed.mediaType != .any {
            nextQuery.mediaType = parsed.mediaType
        }

        if let startDate = parsed.startDate {
            nextQuery.startDate = startDate
        }

        if let endDate = parsed.endDate {
            nextQuery.endDate = endDate
        }

        if parsed.onlyBlurry {
            nextQuery.onlyBlurry = true
            nextQuery.includeBlurred = true
        }

        if parsed.duplicateFilter == .onlyDuplicates {
            nextQuery.duplicateFilter = .onlyDuplicates
        }

        return nextQuery
    }

    private func applyCurrentQuery() {
        isShowingResults = true
        selectedAssetIDs.removeAll()
        isSelectionMode = false

        Task {
            await vm.apply(query: query)
        }
    }

    private func selectionButtonTapped() {
        if !isSelectionMode {
            isSelectionMode = true
            selectedAssetIDs.removeAll()
        } else if selectedAssetIDs.count == vm.assetIDs.count {
            selectedAssetIDs.removeAll()
        } else {
            selectedAssetIDs = Set(vm.assetIDs)
        }
    }

    private func toggleSelection(for assetID: String) {
        guard isSelectionMode else { return }

        if selectedAssetIDs.contains(assetID) {
            selectedAssetIDs.remove(assetID)
        } else {
            selectedAssetIDs.insert(assetID)
        }
    }

    private func returnHome() {
        promptText = ""
        query = PhotoSearchQuery()
        selectedQuickAction = nil
        selectedAssetIDs.removeAll()
        isSelectionMode = false
        showFilters = false
        isShowingResults = false
        vm.showHome()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
