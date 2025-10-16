//
//  MLClassifier.swift
//  PicSea
//

import Foundation
import Vision

//struct ImageFile {
//    var url: URL
//    var observations: [String: VNConfidence] = [:]
//}
//
//struct MLClassifier {
//    static func classifyImage(url: URL) async throws -> ImageFile {
//        var image = ImageFile(url: url)
//        let request = ClassifyImageRequest()
//
//        let results = try await request.perform(on: url)
//            .filter { $0.hasMinimumPrecision(0.1, forRecall: 0.8) }
//
//        for classification in results {
//            image.observations[classification.identifier] = classification.confidence
//        }
//
//        return image
//    }
//}
//
//
