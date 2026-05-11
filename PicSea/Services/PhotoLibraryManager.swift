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

    static func isScreenshotAsset(_ asset: PHAsset, screenshotAssetIdentifiers: Set<String>) -> Bool {
        asset.mediaSubtypes.contains(.photoScreenshot) ||
        screenshotAssetIdentifiers.contains(asset.localIdentifier)
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
                                similarityThreshold: Float = 0.12,
                                targetSize: CGSize = CGSize(width: 224, height: 224)) async -> [PHAsset] {
        let indexedAssets = Array(assets.enumerated())
        let workerCount = min(maxConcurrentImageAnalysisTasks, indexedAssets.count)

        guard workerCount > 0 else {
            return []
        }

        let featurePrints = await withTaskGroup(of: [(Int, PHAsset, VNFeaturePrintObservation)].self) { group in
            for workerIndex in 0..<workerCount {
                group.addTask {
                    var workerFeaturePrints: [(Int, PHAsset, VNFeaturePrintObservation)] = []
                    var currentIndex = workerIndex

                    while currentIndex < indexedAssets.count {
                        let (index, asset) = indexedAssets[currentIndex]

                        if let image = await requestImage(for: asset, targetSize: targetSize),
                           let featurePrint = featurePrintObservation(for: image) {
                            workerFeaturePrints.append((index, asset, featurePrint))
                        }

                        currentIndex += workerCount
                    }

                    return workerFeaturePrints
                }
            }

            var observations: [(Int, PHAsset, VNFeaturePrintObservation)] = []
            for await workerFeaturePrints in group {
                observations.append(contentsOf: workerFeaturePrints)
            }

            return observations.sorted { $0.0 < $1.0 }
        }

        guard featurePrints.count > 1 else {
            return []
        }

        var duplicateIndices = Set<Int>()

        for leftIndex in 0..<(featurePrints.count - 1) {
            let leftObservation = featurePrints[leftIndex].2

            for rightIndex in (leftIndex + 1)..<featurePrints.count {
                let rightObservation = featurePrints[rightIndex].2
                var distance: Float = .greatestFiniteMagnitude

                do {
                    try leftObservation.computeDistance(&distance, to: rightObservation)
                } catch {
                    continue
                }

                if distance <= similarityThreshold {
                    duplicateIndices.insert(leftIndex)
                    duplicateIndices.insert(rightIndex)
                }
            }
        }

        return duplicateIndices
            .sorted()
            .map { featurePrints[$0].1 }
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

    private static func featurePrintObservation(for image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    private static func grayscalePixels(for image: UIImage) -> (width: Int, height: Int, pixels: [UInt8])? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
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
