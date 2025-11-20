//
//  VisionClassifier.swift
//  PicSea
//

import Foundation
import Vision
import UIKit

struct VisionClassifier {

    static func classify(image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        try handler.perform([request])

        let results = request.results ?? []
        return results.map { $0.identifier.lowercased() }
    }
}
