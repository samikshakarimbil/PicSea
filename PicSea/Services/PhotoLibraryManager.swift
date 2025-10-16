//
//  PhotoLibraryManager.swift
//  PicSea
//

import Foundation
import Photos
import UIKit

struct PhotoLibraryManager {
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
}
