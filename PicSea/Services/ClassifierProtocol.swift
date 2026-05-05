//
//  ClassifierProtocol.swift
//  PicSea
//

import Photos

protocol ClassifierProtocol {
    var isAvailable: Bool { get }
    func classify(assets: [PHAsset]) async -> [PHAsset]
}
