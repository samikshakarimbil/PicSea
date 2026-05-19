//
//  SearchSessionView.swift
//  PicSea
//

import SwiftUI

struct SearchSessionView: View {
    @ObservedObject var vm: PhotoLibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query: PhotoSearchQuery
    @State private var promptText: String
    @State private var isApplyingFilters = false

    private let parser = PromptParser()

    init(vm: PhotoLibraryViewModel, query: PhotoSearchQuery) {
        self.vm = vm
        _query = State(initialValue: query)
        _promptText = State(initialValue: query.originalText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterEditor
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                PhotoAssetGrid(assetIDs: vm.assetIDs, onInteractionChanged: { isActive in
                    vm.setUserInteractionActive(isActive)
                })
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        vm.showHome()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                searchBar
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
            }
            .onAppear {
                applyFilters()
            }
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
                    applyPromptAndRefresh()
                }

            Button {
                applyPromptAndRefresh()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplyingFilters || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
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

            Button {
                applyFilters()
            } label: {
                if isApplyingFilters {
                    ProgressView()
                } else {
                    Label("Apply Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplyingFilters)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func applyPromptAndRefresh() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let parsed = parser.parse(trimmed)
        query.originalText = parsed.originalText
        query.concepts = parsed.concepts
        query.mediaType = parsed.mediaType
        query.startDate = parsed.startDate
        query.endDate = parsed.endDate
        query.includeBlurred = parsed.includeBlurred
        query.onlyBlurry = parsed.onlyBlurry
        query.duplicateFilter = parsed.duplicateFilter

        applyFilters()
    }

    private func applyFilters() {
        isApplyingFilters = true

        Task {
            await vm.apply(query: query)
            isApplyingFilters = false
        }
    }
}
