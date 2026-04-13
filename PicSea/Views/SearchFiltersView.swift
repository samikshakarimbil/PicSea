//
//  SearchResultsView.swift
//  PicSea
//

import SwiftUI
import Photos

struct SearchResultsView: View {
    @ObservedObject var vm: PhotoLibraryViewModel

    @State private var query: PhotoSearchQuery
    @State private var promptText: String
    @State private var showFilters = false

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
        VStack(spacing: 0) {
            searchBarSection
            filterSummarySection

            if showFilters {
                filterEditor
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            if vm.isFilteredResults && !vm.assets.isEmpty {
                saveSection
            }

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                    ForEach(vm.assets, id: \.localIdentifier) { asset in
                        AssetThumbnail(asset: asset, size: 100)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
            }
        }
        .navigationTitle("PicSea")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAlbumPrompt) {
            AlbumCreationView(albumName: $albumNameInput) {
                showAlbumPrompt = false
                let finalName = albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "PicSea Results"
                    : albumNameInput.trimmingCharacters(in: .whitespacesAndNewlines)

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

            Button("Apply") {
                applyPromptAndRefresh()
            }
            .buttonStyle(.borderedProminent)
            .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
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

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Start Date", isOn: Binding(
                        get: { query.startDate != nil },
                        set: { isOn in
                            query.startDate = isOn ? (query.startDate ?? Date()) : nil
                        }
                    ))

                    if query.startDate != nil {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { query.startDate ?? Date() },
                                set: { query.startDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("End Date", isOn: Binding(
                        get: { query.endDate != nil },
                        set: { isOn in
                            query.endDate = isOn ? (query.endDate ?? Date()) : nil
                        }
                    ))

                    if query.endDate != nil {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { query.endDate ?? Date() },
                                set: { query.endDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
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
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var saveSection: some View {
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
        .padding(.bottom, 8)
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

        return parts.isEmpty ? "More filters" : parts.joined(separator: " • ")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func applyPromptAndRefresh() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let parsed = parser.parse(trimmed)

        query.originalText = parsed.originalText
        query.concepts = parsed.concepts

        if query.mediaType == .any {
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

        applyFilters()
    }

    private func applyFilters() {
        Task {
            let results = await vm.search(in: vm.allAssets, query: query)
            vm.assets = results
            vm.isFilteredResults = true
        }
    }
}
