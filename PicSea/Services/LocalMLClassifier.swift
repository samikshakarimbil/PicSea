//
//  LocalMLClassifier.swift
//  PicSea
//

import Photos

final class LocalMLClassifier: ClassifierProtocol {
    let isAvailable = true

    func classify(assets: [PHAsset]) async -> [PHAsset] {
        guard !assets.isEmpty else { return [] }

        print("LocalMLClassifier placeholder is running. Returning a random subset of assets.")

        let threshold = Double.random(in: 0.2...0.5)
        return assets.filter { _ in
            Double.random(in: 0...1) < threshold
        }
    }
}
