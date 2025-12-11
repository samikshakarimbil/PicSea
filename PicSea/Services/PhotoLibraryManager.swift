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
}
