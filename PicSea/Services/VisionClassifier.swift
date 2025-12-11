//
//  VisionClassifier.swift
//  PicSea
//

import Foundation
import Vision
import Photos
import UIKit

final class VisionClassifier: ClassifierProtocol {

    var isAvailable: Bool {
        let request = VNClassifyImageRequest()
        guard type(of: request).supportedRevisions.contains(request.revision) else {
            return false
        }

        // Attempt a dummy request to detect runtime availability
        guard let testImage = UIImage(systemName: "photo")?.cgImage else {
            return false
        }

        let handler = VNImageRequestHandler(cgImage: testImage, options: [:])
        do {
            try handler.perform([request])
            return true
        } catch {
            print("Vision unavailable at runtime:", error)
            return false
        }
    }
    
    func classify(assets: [PHAsset]) async -> [PHAsset] {
        guard isAvailable else {
            print("VisionClassifier not available, returning empty array")
            return []
        }

        // TODO: Implement real Vision classification later
        return assets
    }
}
