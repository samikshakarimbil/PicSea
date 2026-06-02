//
//  PicSeaTests.swift
//  PicSeaTests
//

import CoreImage
import Photos
import SwiftData
import Testing
import UIKit
@testable import PicSea

struct PicSeaTests {
    @Test func parserExtractsKeywordsAndMetadata() async throws {
        let parser = PromptParser()
        let query = parser.parse("show me beach photos with my dog from 2024")

        #expect(query.mediaType == .photo)
        #expect(query.startDate != nil)
        #expect(query.endDate != nil)
        #expect(query.searchTokens.contains("beach"))
        #expect(query.searchTokens.contains("dog"))
        #expect(query.concepts == query.searchTokens)
    }

    @Test func parserSupportsQuotedPhrasesAndDuplicateIntent() async throws {
        let parser = PromptParser()
        let query = parser.parse("duplicate \"red car\" selfies")

        #expect(query.mediaType == .selfie)
        #expect(query.duplicateFilter == .onlyDuplicates)
        #expect(query.searchTokens.contains("red car"))
    }

    @Test func parserExpandsDressVariants() async throws {
        let parser = PromptParser()
        let query = parser.parse("dress")

        #expect(query.searchTokens.contains("dress"))
        #expect(query.searchTokens.contains("gown"))
        #expect(query.searchTokens.contains("outfit"))
    }

    @Test @MainActor func storeSearchMatchesVisionLabels() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PhotoIndexRecord.self, configurations: configuration)
        let context = ModelContext(container)
        let store = PhotoIndexStore(context: context)

        let record = PhotoIndexRecord(
            assetLocalIdentifier: "asset-1",
            creationDate: Date(),
            pixelWidth: 100,
            pixelHeight: 100,
            mediaTypeRawValue: PHAssetMediaType.image.rawValue,
            mediaSubtypesRawValue: 0,
            isScreenshot: false,
            isSelfie: false,
            indexingStatus: .indexed,
            indexVersion: PhotoIndexStore.currentIndexVersion,
            cameraRollIndex: 0
        )

        context.insert(record)
        store.markVisionIndexed(record: record, labels: ["dog", "beach"])
        store.saveChanges()

        let query = PromptParser().parse("dog")
        let results = store.search(query: query)

        #expect(results == ["asset-1"])
    }

    @Test @MainActor func storeSearchMatchesPluralizedVisionLabels() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PhotoIndexRecord.self, configurations: configuration)
        let context = ModelContext(container)
        let store = PhotoIndexStore(context: context)

        let record = PhotoIndexRecord(
            assetLocalIdentifier: "asset-2",
            creationDate: Date(),
            pixelWidth: 100,
            pixelHeight: 100,
            mediaTypeRawValue: PHAssetMediaType.image.rawValue,
            mediaSubtypesRawValue: 0,
            isScreenshot: false,
            isSelfie: false,
            indexingStatus: .indexed,
            indexVersion: PhotoIndexStore.currentIndexVersion,
            cameraRollIndex: 0
        )

        context.insert(record)
        store.markVisionIndexed(record: record, labels: ["dresses"])
        store.saveChanges()

        let query = PromptParser().parse("dress")
        let results = store.search(query: query)

        #expect(results == ["asset-2"])
    }

    @Test @MainActor func storeSearchMatchesDressSynonyms() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PhotoIndexRecord.self, configurations: configuration)
        let context = ModelContext(container)
        let store = PhotoIndexStore(context: context)

        let record = PhotoIndexRecord(
            assetLocalIdentifier: "asset-3",
            creationDate: Date(),
            pixelWidth: 100,
            pixelHeight: 100,
            mediaTypeRawValue: PHAssetMediaType.image.rawValue,
            mediaSubtypesRawValue: 0,
            isScreenshot: false,
            isSelfie: false,
            indexingStatus: .indexed,
            indexVersion: PhotoIndexStore.currentIndexVersion,
            cameraRollIndex: 0
        )

        context.insert(record)
        store.markVisionIndexed(record: record, labels: ["evening gown"])
        store.saveChanges()

        let query = PromptParser().parse("dress")
        let results = store.search(query: query)

        #expect(results == ["asset-3"])
    }

    @Test func blurScoreIsLowerForBlurredImage() throws {
        let sharpImage = Self.makeCheckerboardImage()
        let blurredImage = try Self.gaussianBlurredImage(from: sharpImage, radius: 8)

        let sharpScore = PhotoLibraryManager.blurScore(for: sharpImage)
        let blurredScore = PhotoLibraryManager.blurScore(for: blurredImage)

        #expect(sharpScore > blurredScore)
    }

    private static func makeCheckerboardImage(size: CGSize = CGSize(width: 240, height: 240),
                                              squaresPerSide: Int = 8) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let squareWidth = size.width / CGFloat(squaresPerSide)
            let squareHeight = size.height / CGFloat(squaresPerSide)

            for row in 0..<squaresPerSide {
                for column in 0..<squaresPerSide {
                    let isDark = (row + column).isMultiple(of: 2)
                    let color = isDark ? UIColor.black : UIColor.white
                    color.setFill()
                    context.fill(CGRect(
                        x: CGFloat(column) * squareWidth,
                        y: CGFloat(row) * squareHeight,
                        width: squareWidth,
                        height: squareHeight
                    ))
                }
            }
        }
    }

    private static func gaussianBlurredImage(from image: UIImage, radius: CGFloat) throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw NSError(domain: "PicSeaTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create CIImage"])
        }

        guard let filter = CIFilter(name: "CIGaussianBlur") else {
            throw NSError(domain: "PicSeaTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create blur filter"])
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)

        guard let outputImage = filter.outputImage?.cropped(to: ciImage.extent) else {
            throw NSError(domain: "PicSeaTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to blur image"])
        }

        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputImage, from: ciImage.extent) else {
            throw NSError(domain: "PicSeaTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to render blurred image"])
        }

        return UIImage(cgImage: cgImage)
    }
}
