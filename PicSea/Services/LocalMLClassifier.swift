//
//  LocalMLClassifier.swift
//  PicSea
//

import Photos
final class LocalMLClassifier: ClassifierProtocol {
    let isAvailable = true

    func classify(assets: [PHAsset]) async -> [PHAsset] {
        guard !assets.isEmpty else { return [] }

        let threshold = Double.random(in: 0.2...0.5)
        print("LocalMLClassifier running search. Threshold: \(threshold)")

        // Only randomly select photos once per search
        let selected = assets.filter { _ in Double.random(in: 0...1) < threshold }
        return selected
    }
}
