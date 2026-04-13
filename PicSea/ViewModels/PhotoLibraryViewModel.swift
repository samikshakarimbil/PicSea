//
//  PhotoLibraryViewModel.swift
//  PicSea
//

import Foundation
import Photos
import UIKit

final class PhotoLibraryViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published var assets: [PHAsset] = []
    @Published var allAssets: [PHAsset] = []
    @Published var authorized = false
    @Published var isFilteredResults = false

    private let classifier: ClassifierProtocol

    init(classifier: ClassifierProtocol) {
        self.classifier = classifier
        super.init()
        checkAuthorization()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func checkAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            authorized = true
            fetchPhotos()
        case .notDetermined:
            authorized = false
        default:
            authorized = false
        }
    }

    func loadPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkAuthorization()
            }
        }
    }

    func fetchPhotos() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let fetchedAssets = PHAsset.fetchAssets(with: .image, options: options)
        var tempAssets: [PHAsset] = []

        fetchedAssets.enumerateObjects { asset, _, _ in
            tempAssets.append(asset)
        }

        DispatchQueue.main.async {
            self.allAssets = tempAssets
            self.assets = tempAssets
        }
    }

    func resetAssets() {
        assets = allAssets
        isFilteredResults = false
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            self.fetchPhotos()
        }
    }

    func fetchAlbum(named name: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "localizedTitle = %@", name)

        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: options
        )

        return result.firstObject
    }

    func createAlbumIfNeeded(named name: String, completion: @escaping (String?, Error?) -> Void) {
        if let existingAlbum = fetchAlbum(named: name) {
            completion(existingAlbum.localIdentifier, nil)
            return
        }

        var placeholder: PHObjectPlaceholder?

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = request.placeholderForCreatedAssetCollection
        }) { success, error in
            DispatchQueue.main.async {
                if success, let localIdentifier = placeholder?.localIdentifier {
                    completion(localIdentifier, nil)
                } else {
                    completion(nil, error)
                }
            }
        }
    }

    private func addAssets(_ assets: [PHAsset], toAlbumId localId: String, completion: @escaping (Bool, Error?) -> Void) {
        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localId], options: nil)

        guard let album = fetchResult.firstObject else {
            let error = NSError(
                domain: "PicSea",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Album not found"]
            )
            completion(false, error)
            return
        }

        guard !assets.isEmpty else {
            completion(true, nil)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            if let changeRequest = PHAssetCollectionChangeRequest(for: album) {
                changeRequest.addAssets(assets as NSArray)
            }
        }) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    func saveResultsToAlbum(named name: String, completion: @escaping (Bool, Error?) -> Void) {
        let assetsToSave = assets

        createAlbumIfNeeded(named: name) { albumId, error in
            guard let albumId, error == nil else {
                completion(false, error)
                return
            }

            self.addAssets(assetsToSave, toAlbumId: albumId, completion: completion)
        }
    }
}

extension PhotoLibraryViewModel {
    @MainActor
    func runAIClassification() async -> [PHAsset] {
        await classifier.classify(assets: assets)
    }

    @MainActor
    func search(in assets: [PHAsset], prompt: String) async -> [PHAsset] {
        let query = prompt
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            isFilteredResults = false
            return allAssets
        }

        isFilteredResults = true

        var filteredAssets = assets

        if let year = Int(query), query.count == 4 {
            filteredAssets = filteredAssets.filter { asset in
                guard let date = asset.creationDate else { return false }
                return Calendar.current.component(.year, from: date) == year
            }
        }

        return await classifier.classify(assets: filteredAssets)
    }
    
    @MainActor
    func search(in assets: [PHAsset], query: PhotoSearchQuery) async -> [PHAsset] {
        var filteredAssets = assets

        if let startDate = query.startDate {
            filteredAssets = filteredAssets.filter { asset in
                guard let creationDate = asset.creationDate else { return false }
                return creationDate >= startDate
            }
        }

        if let endDate = query.endDate {
            filteredAssets = filteredAssets.filter { asset in
                guard let creationDate = asset.creationDate else { return false }
                return creationDate <= endDate
            }
        }

        switch query.mediaType {
        case .any:
            break
        case .photo:
            filteredAssets = filteredAssets.filter { $0.mediaType == .image }
        case .screenshot:
            filteredAssets = filteredAssets.filter {
                $0.mediaSubtypes.contains(.photoScreenshot)
            }
        case .selfie:
            break
        }

        if !query.concepts.isEmpty {
            filteredAssets = await classifier.classify(assets: filteredAssets)
        }

        return filteredAssets
    }


    func requestThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 256, height: 256),
                contentMode: .aspectFill,
                options: nil
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
