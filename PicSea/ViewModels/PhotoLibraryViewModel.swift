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
    @Published var candidateAssetIDs: [String] = []
    @Published var confirmedResultAssetIDs: [String] = []
    @Published var scannedCount = 0
    @Published var totalCount = 0
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
        candidateAssetIDs = []
        confirmedResultAssetIDs = []
        scannedCount = 0
        totalCount = allAssetIDs.count
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

    func prepareForSearch(query: PhotoSearchQuery) {
        activeQuery = query
        candidateAssetIDs = allAssetIDs
        replaceConfirmedResults(with: indexStore.search(query: query))
        isFilteredResults = true
        updateCoreIndexingProgressText()

        let searchTokens = query.searchTokens.isEmpty ? query.concepts : query.searchTokens
        shouldPrioritizeVisionIndexing = !searchTokens.isEmpty

        if !isIndexing {
            startIndexingPipeline()
        }
    }

    func apply(query: PhotoSearchQuery) async {
        prepareForSearch(query: query)
    }

    func apply(quickAction: PhotoQuickAction) {
        activeQuery = query(for: quickAction)
        candidateAssetIDs = allAssetIDs
        replaceConfirmedResults(with: indexStore.search(query: activeQuery))
        isFilteredResults = true
        updateCoreIndexingProgressText()
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

            updateCoreIndexingProgressText()
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

            updateCoreIndexingProgressText()

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
            updateCoreIndexingProgressText()
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
        scannedCount = progress.indexed
        totalCount = progress.total
        indexingStatusText = "Scanning photos... \(scannedCount) / \(totalCount)"

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
                let classifications = try await PhotoLibraryManager.generateVisionClassifications(for: image)
                indexStore.markVisionIndexed(record: record, classifications: classifications)
            } catch {
                indexStore.markVisionIndexed(record: record, labels: [])
            }
        }

        indexStore.saveChanges()
        let updatedProgress = indexStore.visionIndexProgress()
        scannedCount = updatedProgress.indexed
        totalCount = updatedProgress.total
        indexingStatusText = "Scanning photos... \(scannedCount) / \(totalCount)"
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
            appendConfirmedResults(indexStore.search(query: activeQuery))
        } else {
            assetIDs = allAssetIDs
        }
    }

    private func replaceConfirmedResults(with assetIDs: [String]) {
        let orderedAssetIDs = orderedAssetIDs(from: assetIDs)
        confirmedResultAssetIDs = orderedAssetIDs
        self.assetIDs = orderedAssetIDs
    }

    private func appendConfirmedResults(_ assetIDs: [String]) {
        let mergedAssetIDs = Set(confirmedResultAssetIDs).union(assetIDs)
        replaceConfirmedResults(with: Array(mergedAssetIDs))
    }

    private func orderedAssetIDs(from assetIDs: [String]) -> [String] {
        let assetIDSet = Set(assetIDs)
        return allAssetIDs.filter { assetIDSet.contains($0) }
    }

    private func updateCoreIndexingProgressText() {
        let progress = indexStore.coreIndexProgress()
        scannedCount = progress.indexed
        totalCount = progress.total
        indexingStatusText = "Scanning photos... \(scannedCount) / \(totalCount)"
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

    func printVisionClassifications(for assetID: String) async {
        print(await visionClassificationsDebugText(for: assetID))
    }

    func visionClassificationsDebugText(for assetID: String) async -> String {
        guard let asset = PhotoLibraryManager.asset(for: assetID),
              let image = await PhotoLibraryManager.requestThumbnail(
                for: asset,
                targetSize: CGSize(width: 512, height: 512)
              ) else {
            return "Vision debug failed: could not load thumbnail for \(assetID)"
        }

        do {
            let classifications = try await PhotoLibraryManager.generateVisionClassifications(
                for: image,
                confidenceThreshold: 0,
                limit: 20
            )

            guard !classifications.isEmpty else {
                return "No Vision classifications returned for \(assetID)."
            }

            let lines = classifications.enumerated().map { index, classification in
                "\(index + 1). \(classification.identifier) - \(String(format: "%.4f", classification.confidence))"
            }

            return "Top Vision classifications for \(assetID):\n\n\(lines.joined(separator: "\n"))"
        } catch {
            return "Vision debug failed for \(assetID): \(error)"
        }
    }

    func dumpVisionSupportedIdentifiers() {
        do {
            _ = try PhotoLibraryManager.writeSupportedClassificationIdentifiersDebugFile()
        } catch {
            print("Vision supported identifiers dump failed: \(error)")
        }
    }
}

extension PhotoLibraryViewModel: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            self.refreshLibrary()
        }
    }
}
