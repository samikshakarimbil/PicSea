//
//  PhotoLibraryViewModel.swift
//  PicSea
//

import Foundation
import Photos
import SwiftData
import UIKit

@MainActor
final class PhotoLibraryViewModel: NSObject, ObservableObject {
    @Published var assetIDs: [String] = []
    @Published var allAssetIDs: [String] = []
    @Published var authorized = false
    @Published var isFilteredResults = false
    @Published var isIndexing = false
    @Published var indexingStatusText = ""
    @Published var duplicateSensitivity: DuplicateSimilaritySensitivity = .medium

    private let classifier: ClassifierProtocol
    private let indexStore: PhotoIndexStore
    private var indexingTask: Task<Void, Never>?
    private var isUserInteracting = false
    private var activeQuery = PhotoSearchQuery()
    private var shouldPrioritizeVisionIndexing = false

    init(classifier: ClassifierProtocol, modelContext: ModelContext) {
        self.classifier = classifier
        self.indexStore = PhotoIndexStore(context: modelContext)
        super.init()
        checkAuthorization()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        indexingTask?.cancel()
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func checkAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            authorized = true
            refreshLibrary()
        case .notDetermined:
            authorized = false
        default:
            authorized = false
        }
    }

    func loadPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] _ in
            Task { @MainActor in
                self?.checkAuthorization()
            }
        }
    }

    func refreshLibrary() {
        let assets = PhotoLibraryManager.fetchAllPhotos()
        indexStore.upsertMetadata(for: assets)

        allAssetIDs = indexStore.orderedAssetIDs()

        if !isFilteredResults {
            assetIDs = allAssetIDs
        }

        startIndexingPipeline()
    }

    func resetAssets() {
        assetIDs = allAssetIDs
        isFilteredResults = false
        activeQuery = PhotoSearchQuery()
        shouldPrioritizeVisionIndexing = false
    }

    func showHome() {
        resetAssets()
    }

    func setUserInteractionActive(_ isActive: Bool) {
        isUserInteracting = isActive
    }

    func apply(query: PhotoSearchQuery) async {
        isUserInteracting = true
        defer { isUserInteracting = false }

        activeQuery = query
        assetIDs = indexStore.search(query: query)
        isFilteredResults = true

        let searchTokens = query.searchTokens.isEmpty ? query.concepts : query.searchTokens
        if !searchTokens.isEmpty {
            shouldPrioritizeVisionIndexing = true

            if !isIndexing {
                startIndexingPipeline()
            }
        }
    }

    func apply(quickAction: PhotoQuickAction) {
        activeQuery = query(for: quickAction)
        assetIDs = indexStore.search(query: activeQuery)
        isFilteredResults = true
    }

    func setDuplicateSensitivity(_ sensitivity: DuplicateSimilaritySensitivity) {
        guard duplicateSensitivity != sensitivity else {
            return
        }

        duplicateSensitivity = sensitivity
        rebuildDuplicateGroupsForCurrentSensitivity()
        startIndexingPipeline()
    }

    private func startIndexingPipeline() {
        indexingTask?.cancel()
        indexingTask = Task { [weak self] in
            await self?.runIndexingPipeline()
        }
    }

    private func runIndexingPipeline() async {
        isIndexing = true
        defer {
            isIndexing = false
            indexingStatusText = ""
        }

        while !Task.isCancelled {
            if isUserInteracting {
                indexingStatusText = "Indexing paused"
                try? await Task.sleep(nanoseconds: 500_000_000)
                continue
            }

            if shouldPrioritizeVisionIndexing {
                if await indexVisionLabelsIfNeeded() {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    continue
                } else {
                    shouldPrioritizeVisionIndexing = false
                }
            }

            let batch = indexStore.pendingRecords(limit: IndexingBatchSize.blur)

            if batch.isEmpty {
                indexStore.rebuildDuplicateGroups(sensitivity: duplicateSensitivity)

                let visionBatch = indexStore.recordsNeedingVisionLabels(limit: IndexingBatchSize.vision)

                if !visionBatch.isEmpty {
                    await processVisionBatch(visionBatch)
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    continue
                }

                await refineDuplicateGroupsWithVision()
                indexingStatusText = "Index ready"
                allAssetIDs = indexStore.orderedAssetIDs()
                refreshVisibleResultsIfNeeded()
                break
            }

            indexingStatusText = "Indexing \(batch.count) photos"

            for record in batch {
                guard !Task.isCancelled else { return }

                if isUserInteracting {
                    break
                }

                guard let asset = PhotoLibraryManager.asset(for: record.assetLocalIdentifier),
                      let image = await PhotoLibraryManager.requestThumbnail(
                        for: asset,
                        targetSize: CGSize(width: 256, height: 256)
                      ) else {
                    indexStore.markIndexed(assetID: record.assetLocalIdentifier, blurScore: nil, perceptualHash: nil)
                    continue
                }

                let blurScore = PhotoLibraryManager.blurScore(for: image)
                let perceptualHashes = PhotoLibraryManager.perceptualHashes(for: image)
                let perceptualHashBundle = perceptualHashes.isEmpty ? nil : perceptualHashes.joined(separator: ",")
                indexStore.markIndexed(assetID: record.assetLocalIdentifier, blurScore: blurScore, perceptualHash: perceptualHashBundle)
            }

            indexStore.rebuildDuplicateGroups(sensitivity: duplicateSensitivity)
            refreshVisibleResultsIfNeeded()
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }

    private func indexVisionLabelsIfNeeded() async -> Bool {
        let visionBatch = indexStore.recordsNeedingVisionLabels(limit: IndexingBatchSize.vision)

        guard !visionBatch.isEmpty else {
            return false
        }

        await processVisionBatch(visionBatch)
        return true
    }

    private func processVisionBatch(_ records: [PhotoIndexRecord]) async {
        let progress = indexStore.visionIndexProgress()
        indexingStatusText = "Scanning photos... \(progress.indexed) / \(progress.total)"

        for record in records {
            guard !Task.isCancelled else { return }

            if isUserInteracting {
                break
            }

            guard let asset = PhotoLibraryManager.asset(for: record.assetLocalIdentifier),
                  let image = await PhotoLibraryManager.requestThumbnail(for: asset) else {
                indexStore.markVisionIndexed(record: record, labels: [])
                continue
            }

            do {
                let labels = try await PhotoLibraryManager.generateVisionLabels(for: image)
                indexStore.markVisionIndexed(record: record, labels: labels)
            } catch {
                indexStore.markVisionIndexed(record: record, labels: [])
            }
        }

        indexStore.saveChanges()
        let updatedProgress = indexStore.visionIndexProgress()
        indexingStatusText = "Scanning photos... \(updatedProgress.indexed) / \(updatedProgress.total)"
        refreshVisibleResultsIfNeeded()
    }

    private func refineDuplicateGroupsWithVision() async {
        guard !isUserInteracting else {
            return
        }

        indexingStatusText = "Refining duplicates"
        let assets = PhotoLibraryManager.assets(for: allAssetIDs)
        let groups = await PhotoLibraryManager.similarAssetIdentifierGroups(
            from: assets,
            minimumSimilarity: duplicateSensitivity.visionMinimumSimilarity
        )

        guard !Task.isCancelled else {
            return
        }

        indexStore.applyDuplicateGroups(groups)
    }

    private func rebuildDuplicateGroupsForCurrentSensitivity() {
        indexStore.rebuildDuplicateGroups(sensitivity: duplicateSensitivity)

        if isFilteredResults {
            refreshVisibleResultsIfNeeded()
        }
    }

    private func refreshVisibleResultsIfNeeded() {
        if isFilteredResults {
            assetIDs = indexStore.search(query: activeQuery)
        } else {
            assetIDs = allAssetIDs
        }
    }

    private func query(for quickAction: PhotoQuickAction) -> PhotoSearchQuery {
        var query = PhotoSearchQuery()

        switch quickAction {
        case .duplicates:
            query.duplicateFilter = .onlyDuplicates
        case .blurry:
            query.onlyBlurry = true
            query.duplicateFilter = .include
        case .screenshots:
            query.mediaType = .screenshot
            query.duplicateFilter = .include
        case .selfies:
            query.mediaType = .selfie
            query.duplicateFilter = .include
        }

        return query
    }

    func fetchAlbum(named name: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "localizedTitle = %@", name)

        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: options
        )

        return result.firstObject
    }

    func createAlbumIfNeeded(named name: String, completion: @escaping (String?, Error?) -> Void) {
        if let existingAlbum = fetchAlbum(named: name) {
            completion(existingAlbum.localIdentifier, nil)
            return
        }

        var placeholder: PHObjectPlaceholder?

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = request.placeholderForCreatedAssetCollection
        }) { success, error in
            DispatchQueue.main.async {
                if success, let localIdentifier = placeholder?.localIdentifier {
                    completion(localIdentifier, nil)
                } else {
                    completion(nil, error)
                }
            }
        }
    }

    private func addAssets(_ assets: [PHAsset], toAlbumId localId: String, completion: @escaping (Bool, Error?) -> Void) {
        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localId], options: nil)

        guard let album = fetchResult.firstObject else {
            let error = NSError(
                domain: "PicSea",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Album not found"]
            )
            completion(false, error)
            return
        }

        guard !assets.isEmpty else {
            completion(true, nil)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            if let changeRequest = PHAssetCollectionChangeRequest(for: album) {
                changeRequest.addAssets(assets as NSArray)
            }
        }) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    func saveResultsToAlbum(named name: String, completion: @escaping (Bool, Error?) -> Void) {
        saveSpecificAssetIDsToAlbum(assetIDs, named: name, completion: completion)
    }

    func saveSpecificAssetIDsToAlbum(_ assetIDs: [String], named name: String, completion: @escaping (Bool, Error?) -> Void) {
        let assetsToSave = PhotoLibraryManager.assets(for: assetIDs)

        createAlbumIfNeeded(named: name) { albumId, error in
            guard let albumId, error == nil else {
                completion(false, error)
                return
            }

            self.addAssets(assetsToSave, toAlbumId: albumId, completion: completion)
        }
    }

    func saveSpecificAssetsToAlbum(_ assets: [PHAsset], named name: String, completion: @escaping (Bool, Error?) -> Void) {
        createAlbumIfNeeded(named: name) { albumId, error in
            guard let albumId, error == nil else {
                completion(false, error)
                return
            }

            self.addAssets(assets, toAlbumId: albumId, completion: completion)
        }
    }

    func requestThumbnail(for asset: PHAsset) async -> UIImage? {
        await PhotoLibraryManager.requestThumbnail(for: asset)
    }
}

extension PhotoLibraryViewModel: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            self.refreshLibrary()
        }
    }
}
