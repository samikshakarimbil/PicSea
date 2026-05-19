//
//  PhotoIndexStore.swift
//  PicSea
//

import Foundation
import Photos
import SwiftData

@MainActor
final class PhotoIndexStore {
    nonisolated static let currentIndexVersion = 2
    nonisolated static let defaultDuplicateWindow = 20
    nonisolated static let mediumDuplicateHashDistance = 14
    nonisolated static let blurryThreshold: Float = 18

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsertMetadata(for assets: [PHAsset]) {
        let screenshotIDs = PhotoLibraryManager.screenshotAssetIdentifiers()
        let selfieIDs = PhotoLibraryManager.selfieAssetIdentifiers()
        let existingRecords = fetchAllRecords()
        var recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.assetLocalIdentifier, $0) })
        let currentIDs = Set(assets.map(\.localIdentifier))

        for staleRecord in existingRecords where !currentIDs.contains(staleRecord.assetLocalIdentifier) {
            context.delete(staleRecord)
        }

        for (cameraRollIndex, asset) in assets.enumerated() {
            let record = recordsByID[asset.localIdentifier] ?? PhotoIndexRecord(
                assetLocalIdentifier: asset.localIdentifier,
                creationDate: asset.creationDate,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                mediaTypeRawValue: asset.mediaType.rawValue,
                mediaSubtypesRawValue: Int(asset.mediaSubtypes.rawValue),
                isScreenshot: PhotoLibraryManager.isScreenshotAsset(asset, screenshotAssetIdentifiers: screenshotIDs),
                isSelfie: selfieIDs.contains(asset.localIdentifier),
                indexVersion: Self.currentIndexVersion,
                cameraRollIndex: cameraRollIndex
            )

            if recordsByID[asset.localIdentifier] == nil {
                context.insert(record)
                recordsByID[asset.localIdentifier] = record
            }

            record.creationDate = asset.creationDate
            record.pixelWidth = asset.pixelWidth
            record.pixelHeight = asset.pixelHeight
            record.mediaTypeRawValue = asset.mediaType.rawValue
            record.mediaSubtypesRawValue = Int(asset.mediaSubtypes.rawValue)
            record.isScreenshot = PhotoLibraryManager.isScreenshotAsset(asset, screenshotAssetIdentifiers: screenshotIDs)
            record.isSelfie = selfieIDs.contains(asset.localIdentifier)
            record.cameraRollIndex = cameraRollIndex

            if record.indexVersion < Self.currentIndexVersion || record.indexingStatus == PhotoIndexingStatus.failed.rawValue {
                record.indexingStatus = PhotoIndexingStatus.pending.rawValue
            }
        }

        save()
    }

    func orderedAssetIDs() -> [String] {
        fetchAllRecords()
            .sorted { $0.cameraRollIndex < $1.cameraRollIndex }
            .map(\.assetLocalIdentifier)
    }

    func pendingRecords(limit: Int) -> [PhotoIndexRecord] {
        fetchAllRecords()
            .filter { record in
                record.indexingStatus != PhotoIndexingStatus.indexed.rawValue ||
                record.indexVersion < Self.currentIndexVersion ||
                record.blurScore == nil ||
                record.perceptualHash == nil
            }
            .sorted { $0.cameraRollIndex < $1.cameraRollIndex }
            .prefix(limit)
            .map { $0 }
    }

    func markIndexed(assetID: String, blurScore: Float?, perceptualHash: String?) {
        guard let record = record(for: assetID) else {
            return
        }

        record.blurScore = blurScore
        record.perceptualHash = perceptualHash
        record.indexingStatus = perceptualHash == nil ? PhotoIndexingStatus.failed.rawValue : PhotoIndexingStatus.indexed.rawValue
        record.lastIndexedAt = Date()
        record.indexVersion = Self.currentIndexVersion
    }

    func rebuildDuplicateGroups(window: Int = defaultDuplicateWindow,
                                maxHashDistance: Int = mediumDuplicateHashDistance) {
        let records = fetchAllRecords().sorted { $0.cameraRollIndex < $1.cameraRollIndex }
        var parent = Dictionary(uniqueKeysWithValues: records.map { ($0.assetLocalIdentifier, $0.assetLocalIdentifier) })
        var bestScores: [String: Float] = [:]

        func root(of id: String) -> String {
            var current = id

            while let next = parent[current], next != current {
                current = next
            }

            return current
        }

        func merge(_ leftID: String, _ rightID: String, score: Float) {
            let leftRoot = root(of: leftID)
            let rightRoot = root(of: rightID)

            guard leftRoot != rightRoot else { return }
            parent[rightRoot] = leftRoot
            bestScores[leftID] = max(bestScores[leftID] ?? 0, score)
            bestScores[rightID] = max(bestScores[rightID] ?? 0, score)
        }

        for leftIndex in 0..<records.count {
            let leftRecord = records[leftIndex]
            let leftHashes = hashes(from: leftRecord)
            guard !leftHashes.isEmpty else { continue }

            let maxRightIndex = min(records.count - 1, leftIndex + window)
            guard leftIndex < maxRightIndex else { continue }

            for rightIndex in (leftIndex + 1)...maxRightIndex {
                let rightRecord = records[rightIndex]
                let rightHashes = hashes(from: rightRecord)
                guard let distance = bestHashDistance(between: leftHashes, and: rightHashes),
                      distance <= maxHashDistance else {
                    continue
                }

                let score = 1 - (Float(distance) / 64)
                merge(leftRecord.assetLocalIdentifier, rightRecord.assetLocalIdentifier, score: score)
            }
        }

        let groupedIDs = Dictionary(grouping: records.map(\.assetLocalIdentifier), by: root)
        let duplicateGroups = groupedIDs.filter { $0.value.count > 1 }

        for record in records {
            guard let group = duplicateGroups.first(where: { $0.value.contains(record.assetLocalIdentifier) }) else {
                record.duplicateGroupID = nil
                record.duplicateScore = nil
                continue
            }

            let representativeID = group.value
                .compactMap { id in records.first(where: { $0.assetLocalIdentifier == id }) }
                .sorted { $0.cameraRollIndex < $1.cameraRollIndex }
                .first?
                .assetLocalIdentifier

            record.duplicateGroupID = representativeID
            record.duplicateScore = bestScores[record.assetLocalIdentifier] ?? 1
        }

        save()
    }

    func applyDuplicateGroups(_ groups: [[String]]) {
        let records = fetchAllRecords()
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.assetLocalIdentifier, $0) })

        for record in records {
            record.duplicateGroupID = nil
            record.duplicateScore = nil
        }

        for group in groups where group.count > 1 {
            let sortedGroup = group
                .compactMap { recordsByID[$0] }
                .sorted { $0.cameraRollIndex < $1.cameraRollIndex }

            guard let representativeID = sortedGroup.first?.assetLocalIdentifier else {
                continue
            }

            for record in sortedGroup {
                record.duplicateGroupID = representativeID
                record.duplicateScore = record.assetLocalIdentifier == representativeID ? 1 : 0.9
            }
        }

        save()
    }

    func search(query: PhotoSearchQuery) -> [String] {
        var records = fetchAllRecords().sorted { $0.cameraRollIndex < $1.cameraRollIndex }
        let calendar = Calendar.current

        if let startDate = query.startDate {
            let normalizedStartDate = calendar.startOfDay(for: startDate)
            records = records.filter { record in
                guard let creationDate = record.creationDate else { return false }
                return creationDate >= normalizedStartDate
            }
        }

        if let endDate = query.endDate,
           let normalizedEndDate = calendar.date(byAdding: DateComponents(day: 1, second: -1),
                                                 to: calendar.startOfDay(for: endDate)) {
            records = records.filter { record in
                guard let creationDate = record.creationDate else { return false }
                return creationDate <= normalizedEndDate
            }
        }

        switch query.mediaType {
        case .any:
            break
        case .photo:
            records = records.filter { $0.mediaTypeRawValue == PHAssetMediaType.image.rawValue && !$0.isScreenshot }
        case .screenshot:
            records = records.filter(\.isScreenshot)
        case .selfie:
            records = records.filter(\.isSelfie)
        }

        if query.onlyBlurry {
            records = records.filter { ($0.blurScore ?? .greatestFiniteMagnitude) < Self.blurryThreshold }
        } else if !query.includeBlurred {
            records = records.filter { ($0.blurScore ?? Self.blurryThreshold) >= Self.blurryThreshold }
        }

        switch query.duplicateFilter {
        case .include:
            break
        case .exclude:
            records = records.filter { record in
                guard let groupID = record.duplicateGroupID else { return true }
                return groupID == record.assetLocalIdentifier
            }
        case .onlyDuplicates:
            records = records.filter { $0.duplicateGroupID != nil }
        }

        return records.map(\.assetLocalIdentifier)
    }

    func assetIDs(forQuickAction quickAction: PhotoQuickAction) -> [String] {
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

        return search(query: query)
    }

    private func record(for assetID: String) -> PhotoIndexRecord? {
        fetchAllRecords().first { $0.assetLocalIdentifier == assetID }
    }

    private func hashes(from record: PhotoIndexRecord) -> [String] {
        record.perceptualHash?
            .split(separator: ",")
            .map(String.init) ?? []
    }

    private func bestHashDistance(between leftHashes: [String], and rightHashes: [String]) -> Int? {
        var bestDistance: Int?

        for leftHash in leftHashes {
            for rightHash in rightHashes {
                guard let distance = PhotoLibraryManager.hammingDistance(between: leftHash, and: rightHash) else {
                    continue
                }

                bestDistance = min(bestDistance ?? distance, distance)
            }
        }

        return bestDistance
    }

    private func fetchAllRecords() -> [PhotoIndexRecord] {
        do {
            var descriptor = FetchDescriptor<PhotoIndexRecord>()
            descriptor.sortBy = [SortDescriptor(\.cameraRollIndex, order: .forward)]
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("Photo index save failed:", error)
        }
    }
}

enum PhotoQuickAction: String, CaseIterable, Identifiable {
    case duplicates
    case blurry
    case screenshots
    case selfies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duplicates: return "Duplicates"
        case .blurry: return "Blurry"
        case .screenshots: return "Screenshots"
        case .selfies: return "Selfies"
        }
    }

    var systemImage: String {
        switch self {
        case .duplicates: return "square.on.square"
        case .blurry: return "camera.filters"
        case .screenshots: return "iphone"
        case .selfies: return "person.crop.square"
        }
    }
}
