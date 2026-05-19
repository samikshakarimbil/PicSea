//
//  PhotoLibraryManager.swift
//  PicSea
//

import Foundation
import Photos
import UIKit
import Vision

struct PhotoLibraryManager {
    private static let maxConcurrentImageAnalysisTasks = 4

    private struct AssetFeaturePrints {
        let assetIndex: Int
        let observations: [VNFeaturePrintObservation]
    }

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                completion(status == .authorized || status == .limited)
            }
        }
    }

    static func fetchAllPhotos() -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    static func screenshotAssetIdentifiers() -> Set<String> {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        )

        guard let screenshotsAlbum = collections.firstObject else {
            return []
        }

        let screenshotAssets = PHAsset.fetchAssets(in: screenshotsAlbum, options: nil)
        var identifiers = Set<String>()

        screenshotAssets.enumerateObjects { asset, _, _ in
            identifiers.insert(asset.localIdentifier)
        }

        return identifiers
    }

    static func selfieAssetIdentifiers() -> Set<String> {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumSelfPortraits,
            options: nil
        )

        guard let selfiesAlbum = collections.firstObject else {
            return []
        }

        let selfieAssets = PHAsset.fetchAssets(in: selfiesAlbum, options: nil)
        var identifiers = Set<String>()

        selfieAssets.enumerateObjects { asset, _, _ in
            identifiers.insert(asset.localIdentifier)
        }

        return identifiers
    }

    static func isScreenshotAsset(_ asset: PHAsset, screenshotAssetIdentifiers: Set<String>) -> Bool {
        asset.mediaSubtypes.contains(.photoScreenshot) ||
        screenshotAssetIdentifiers.contains(asset.localIdentifier)
    }

    static func asset(for localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    static func assets(for localIdentifiers: [String]) -> [PHAsset] {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        var assetsByID: [String: PHAsset] = [:]

        fetchResult.enumerateObjects { asset, _, _ in
            assetsByID[asset.localIdentifier] = asset
        }

        return localIdentifiers.compactMap { assetsByID[$0] }
    }

    static func requestImage(for asset: PHAsset,
                             targetSize: CGSize = CGSize(width: 200, height: 200),
                             completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        manager.requestImage(for: asset,
                             targetSize: targetSize,
                             contentMode: .aspectFill,
                             options: nil) { image, _ in
            completion(image)
        }
    }

    static func requestImage(for asset: PHAsset,
                             targetSize: CGSize = CGSize(width: 256, height: 256)) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }
                continuation.resume(returning: image)
            }
        }
    }

    static func blurryAssets(from assets: [PHAsset],
                             threshold: Float = 18,
                             targetSize: CGSize = CGSize(width: 256, height: 256)) async -> [PHAsset] {
        let indexedAssets = Array(assets.enumerated())
        let workerCount = min(maxConcurrentImageAnalysisTasks, indexedAssets.count)

        guard workerCount > 0 else {
            return []
        }

        let matches = await withTaskGroup(of: [(Int, PHAsset)].self) { group in
            for workerIndex in 0..<workerCount {
                group.addTask {
                    var workerMatches: [(Int, PHAsset)] = []
                    var currentIndex = workerIndex

                    while currentIndex < indexedAssets.count {
                        let (index, asset) = indexedAssets[currentIndex]

                        if let image = await requestImage(for: asset, targetSize: targetSize),
                           sharpnessScore(for: image) < threshold {
                            workerMatches.append((index, asset))
                        }

                        currentIndex += workerCount
                    }

                    return workerMatches
                }
            }

            var matches: [(Int, PHAsset)] = []
            for await workerMatches in group {
                matches.append(contentsOf: workerMatches)
            }

            return matches
        }

        return matches
            .sorted { $0.0 < $1.0 }
            .map(\.1)
    }

    static func duplicateAssets(from assets: [PHAsset],
                                minimumSimilarity: Float = 0.8,
                                neighborWindow: Int = 20,
                                targetSize: CGSize = CGSize(width: 224, height: 224)) async -> [PHAsset] {
        let groups = await similarAssetIndexGroups(
            from: assets,
            minimumSimilarity: minimumSimilarity,
            neighborWindow: neighborWindow,
            targetSize: targetSize
        )

        return Set(groups.flatMap { $0 })
            .sorted()
            .map { assets[$0] }
    }

    static func similarAssetIdentifierGroups(from assets: [PHAsset],
                                             minimumSimilarity: Float = 0.8,
                                             neighborWindow: Int = 20,
                                             targetSize: CGSize = CGSize(width: 224, height: 224)) async -> [[String]] {
        let groups = await similarAssetIndexGroups(
            from: assets,
            minimumSimilarity: minimumSimilarity,
            neighborWindow: neighborWindow,
            targetSize: targetSize
        )

        return groups.map { group in
            group.map { assets[$0].localIdentifier }
        }
    }

    static func assetsExcludingDuplicateExtras(from assets: [PHAsset],
                                               minimumSimilarity: Float = 0.8,
                                               neighborWindow: Int = 20,
                                               targetSize: CGSize = CGSize(width: 224, height: 224)) async -> [PHAsset] {
        let groups = await similarAssetIndexGroups(
            from: assets,
            minimumSimilarity: minimumSimilarity,
            neighborWindow: neighborWindow,
            targetSize: targetSize
        )

        let duplicateExtraIndices = Set(groups.flatMap { $0.dropFirst() })
        return assets.enumerated().compactMap { index, asset in
            duplicateExtraIndices.contains(index) ? nil : asset
        }
    }

    private static func similarAssetIndexGroups(from assets: [PHAsset],
                                                minimumSimilarity: Float,
                                                neighborWindow: Int,
                                                targetSize: CGSize) async -> [[Int]] {
        let indexedAssets = Array(assets.enumerated())
        let workerCount = min(maxConcurrentImageAnalysisTasks, indexedAssets.count)

        guard workerCount > 0, neighborWindow > 0 else {
            return []
        }

        let featurePrints = await withTaskGroup(of: [AssetFeaturePrints].self) { group in
            for workerIndex in 0..<workerCount {
                group.addTask {
                    var workerFeaturePrints: [AssetFeaturePrints] = []
                    var currentIndex = workerIndex

                    while currentIndex < indexedAssets.count {
                        let (index, asset) = indexedAssets[currentIndex]

                        if let image = await requestImage(for: asset, targetSize: targetSize),
                           !Task.isCancelled {
                            let observations = featurePrintObservations(for: image)

                            if !observations.isEmpty {
                                workerFeaturePrints.append(
                                    AssetFeaturePrints(assetIndex: index, observations: observations)
                                )
                            }
                        }

                        currentIndex += workerCount
                    }

                    return workerFeaturePrints
                }
            }

            var observations: [AssetFeaturePrints] = []
            for await workerFeaturePrints in group {
                observations.append(contentsOf: workerFeaturePrints)
            }

            return observations.sorted { $0.assetIndex < $1.assetIndex }
        }

        guard featurePrints.count > 1 else {
            return []
        }

        var groupParents = Dictionary(uniqueKeysWithValues: featurePrints.map { ($0.assetIndex, $0.assetIndex) })
        let normalizedMinimumSimilarity = min(max(minimumSimilarity, 0), 1)

        func root(of index: Int) -> Int {
            var current = index

            while let parent = groupParents[current], parent != current {
                current = parent
            }

            return current
        }

        func merge(_ leftIndex: Int, _ rightIndex: Int) {
            let leftRoot = root(of: leftIndex)
            let rightRoot = root(of: rightIndex)

            guard leftRoot != rightRoot else { return }
            groupParents[rightRoot] = leftRoot
        }

        for leftIndex in 0..<(featurePrints.count - 1) {
            let leftFeaturePrints = featurePrints[leftIndex]

            for rightIndex in (leftIndex + 1)..<featurePrints.count {
                let rightFeaturePrints = featurePrints[rightIndex]
                guard rightFeaturePrints.assetIndex - leftFeaturePrints.assetIndex <= neighborWindow else {
                    break
                }

                if bestSimilarity(
                    between: leftFeaturePrints.observations,
                    and: rightFeaturePrints.observations
                ) >= normalizedMinimumSimilarity {
                    merge(leftFeaturePrints.assetIndex, rightFeaturePrints.assetIndex)
                }
            }
        }

        var groupedIndices: [Int: [Int]] = [:]

        for featurePrint in featurePrints {
            groupedIndices[root(of: featurePrint.assetIndex), default: []].append(featurePrint.assetIndex)
        }

        return groupedIndices.values
            .map { $0.sorted() }
            .filter { $0.count > 1 }
            .sorted { $0[0] < $1[0] }
    }

    static func createAlbum(named name: String,
                            assets: [PHAsset],
                            completion: @escaping (Bool) -> Void) {

        var albumPlaceholder: PHObjectPlaceholder?

        PHPhotoLibrary.shared().performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }, completionHandler: { success, _ in
            guard success,
                  let placeholder = albumPlaceholder else {
                completion(false)
                return
            }

            // Add assets to the album
            let collectionFetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)

            guard let album = collectionFetch.firstObject else {
                completion(false)
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let addRequest = PHAssetCollectionChangeRequest(for: album)
                addRequest?.addAssets(assets as NSArray)
            }, completionHandler: { finished, _ in
                completion(finished)
            })
        })
    }

    private static func sharpnessScore(for image: UIImage) -> Float {
        guard let grayscalePixels = grayscalePixels(for: image), grayscalePixels.pixels.count > 9 else {
            return 0
        }

        let width = grayscalePixels.width
        let height = grayscalePixels.height
        let pixels = grayscalePixels.pixels
        var laplacianValues: [Float] = []
        laplacianValues.reserveCapacity(max(0, (width - 2) * (height - 2)))

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Float(pixels[(y * width) + x]) * 8
                let topLeft = Float(pixels[((y - 1) * width) + (x - 1)])
                let top = Float(pixels[((y - 1) * width) + x])
                let topRight = Float(pixels[((y - 1) * width) + (x + 1)])
                let left = Float(pixels[(y * width) + (x - 1)])
                let right = Float(pixels[(y * width) + (x + 1)])
                let bottomLeft = Float(pixels[((y + 1) * width) + (x - 1)])
                let bottom = Float(pixels[((y + 1) * width) + x])
                let bottomRight = Float(pixels[((y + 1) * width) + (x + 1)])

                let value = center - topLeft - top - topRight - left - right - bottomLeft - bottom - bottomRight
                laplacianValues.append(value)
            }
        }

        guard !laplacianValues.isEmpty else {
            return 0
        }

        let count = Float(laplacianValues.count)
        let mean = laplacianValues.reduce(0, +) / count
        let variance = laplacianValues.reduce(0) { partialResult, value in
            let difference = value - mean
            return partialResult + (difference * difference)
        } / count

        return variance.squareRoot()
    }

    static func blurScore(for image: UIImage) -> Float {
        sharpnessScore(for: image)
    }

    static func perceptualHash(for image: UIImage) -> String? {
        guard let grayscalePixels = grayscalePixels(for: image, width: 8, height: 8),
              grayscalePixels.pixels.count == 64 else {
            return nil
        }

        let average = grayscalePixels.pixels.reduce(0) { $0 + Int($1) } / grayscalePixels.pixels.count
        var hash: UInt64 = 0

        for pixel in grayscalePixels.pixels {
            hash <<= 1

            if Int(pixel) >= average {
                hash |= 1
            }
        }

        return String(format: "%016llx", hash)
    }

    static func perceptualHashes(for image: UIImage) -> [String] {
        guard let cgImage = image.cgImage else {
            return []
        }

        var hashes: [String] = []

        if let fullImageHash = perceptualHash(for: image) {
            hashes.append(fullImageHash)
        }

        let cropSpecs: [(scale: CGFloat, center: CGPoint)] = [
            (0.72, CGPoint(x: 0.5, y: 0.5)),
            (0.55, CGPoint(x: 0.5, y: 0.5)),
            (0.65, CGPoint(x: 0.35, y: 0.35)),
            (0.65, CGPoint(x: 0.65, y: 0.35)),
            (0.65, CGPoint(x: 0.35, y: 0.65)),
            (0.65, CGPoint(x: 0.65, y: 0.65))
        ]

        for cropSpec in cropSpecs {
            guard let croppedImage = croppedImage(from: cgImage, scale: cropSpec.scale, center: cropSpec.center),
                  let cropHash = perceptualHash(for: UIImage(cgImage: croppedImage)) else {
                continue
            }

            hashes.append(cropHash)
        }

        return Array(Set(hashes)).sorted()
    }

    static func hammingDistance(between leftHash: String, and rightHash: String) -> Int? {
        guard let leftValue = UInt64(leftHash, radix: 16),
              let rightValue = UInt64(rightHash, radix: 16) else {
            return nil
        }

        return (leftValue ^ rightValue).nonzeroBitCount
    }

    private static func featurePrintObservations(for image: UIImage) -> [VNFeaturePrintObservation] {
        guard let cgImage = image.cgImage else {
            return []
        }

        var observations: [VNFeaturePrintObservation] = []

        if let fullImageObservation = featurePrintObservation(for: cgImage, cropAndScaleOption: .scaleFit) {
            observations.append(fullImageObservation)
        }

        if let centerCropObservation = featurePrintObservation(for: cgImage, cropAndScaleOption: .centerCrop) {
            observations.append(centerCropObservation)
        }

        let cropSpecs: [(scale: CGFloat, center: CGPoint)] = [
            (0.72, CGPoint(x: 0.5, y: 0.5)),
            (0.55, CGPoint(x: 0.5, y: 0.5)),
            (0.65, CGPoint(x: 0.35, y: 0.35)),
            (0.65, CGPoint(x: 0.65, y: 0.35)),
            (0.65, CGPoint(x: 0.35, y: 0.65)),
            (0.65, CGPoint(x: 0.65, y: 0.65))
        ]

        for cropSpec in cropSpecs {
            guard let croppedImage = croppedImage(from: cgImage, scale: cropSpec.scale, center: cropSpec.center),
                  let cropObservation = featurePrintObservation(for: croppedImage, cropAndScaleOption: .scaleFit) else {
                continue
            }

            observations.append(cropObservation)
        }

        return observations
    }

    private static func featurePrintObservation(for image: CGImage,
                                                cropAndScaleOption: VNImageCropAndScaleOption) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = cropAndScaleOption

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    private static func bestSimilarity(between leftObservations: [VNFeaturePrintObservation],
                                       and rightObservations: [VNFeaturePrintObservation]) -> Float {
        var bestSimilarity: Float = 0

        for leftObservation in leftObservations {
            for rightObservation in rightObservations {
                var distance: Float = .greatestFiniteMagnitude

                do {
                    try leftObservation.computeDistance(&distance, to: rightObservation)
                    bestSimilarity = max(bestSimilarity, similarityScore(forDistance: distance))
                } catch {
                    continue
                }
            }
        }

        return bestSimilarity
    }

    private static func similarityScore(forDistance distance: Float) -> Float {
        guard distance.isFinite, distance >= 0 else {
            return 0
        }

        return max(0, 1 - (distance / 2))
    }

    private static func croppedImage(from image: CGImage, scale: CGFloat, center: CGPoint) -> CGImage? {
        guard scale > 0, scale < 1 else {
            return nil
        }

        let cropWidth = CGFloat(image.width) * scale
        let cropHeight = CGFloat(image.height) * scale
        let originX = min(max((CGFloat(image.width) * center.x) - (cropWidth / 2), 0), CGFloat(image.width) - cropWidth)
        let originY = min(max((CGFloat(image.height) * center.y) - (cropHeight / 2), 0), CGFloat(image.height) - cropHeight)
        let cropRect = CGRect(
            x: originX,
            y: originY,
            width: cropWidth,
            height: cropHeight
        ).integral

        return image.cropping(to: cropRect)
    }

    private static func grayscalePixels(for image: UIImage, width targetWidth: Int? = nil, height targetHeight: Int? = nil) -> (width: Int, height: Int, pixels: [UInt8])? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let width = targetWidth ?? cgImage.width
        let height = targetHeight ?? cgImage.height
        let bytesPerRow = width
        var pixels = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (width, height, pixels)
    }
}
