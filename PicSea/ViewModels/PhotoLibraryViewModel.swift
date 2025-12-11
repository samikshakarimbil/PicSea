//
//  PhotoLibraryViewModel.swift
//  PicSea
//

import Foundation
import SwiftUI
import Photos

class PhotoLibraryViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published var assets: [PHAsset] = []
    @Published var allAssets: [PHAsset] = []
    @Published var authorized: Bool = false
    @Published var isFilteredResults: Bool = false

    // Use the classifier passed from PicSeaApp
    private let classifier: ClassifierProtocol

    
    init(classifier: ClassifierProtocol) {
        self.classifier = classifier
        super.init()
        checkAuthorization()
        PHPhotoLibrary.shared().register(self)
    }
   
    // MARK: - Authorization
    func checkAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            self.authorized = true
            fetchPhotos()
        case .notDetermined:
            self.authorized = false
        default:
            self.authorized = false
        }
    }

    func loadPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.checkAuthorization()
            }
        }
    }

    // MARK: - Fetch Photos

    func fetchPhotos() {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allPhotos = PHAsset.fetchAssets(with: .image, options: opts)
        var temp: [PHAsset] = []
        allPhotos.enumerateObjects { asset, _, _ in temp.append(asset) }
        
        DispatchQueue.main.async {
            self.allAssets = temp       // store full library
            self.assets = temp          // display all by default
        }
    }

    // MARK: - Live updates

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            self.fetchPhotos()
        }
    }

    // MARK: - Album Helpers

    func fetchAlbum(named name: String) -> PHAssetCollection? {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "localizedTitle = %@", name)
        let res = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: opts)
        return res.firstObject
    }

    func createAlbumIfNeeded(named name: String, completion: @escaping (String?, Error?) -> Void) {
        if let existing = fetchAlbum(named: name) {
            completion(existing.localIdentifier, nil)
            return
        }

        var placeholder: PHObjectPlaceholder?

        PHPhotoLibrary.shared().performChanges({
            let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = req.placeholderForCreatedAssetCollection
        }) { success, error in
            DispatchQueue.main.async {
                if success, let id = placeholder?.localIdentifier {
                    completion(id, nil)
                } else {
                    completion(nil, error)
                }
            }
        }
    }

    private func addAssets(_ assets: [PHAsset], toAlbumId localId: String, completion: @escaping (Bool, Error?) -> Void) {
        let fetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localId], options: nil)
        guard let album = fetch.firstObject else {
            completion(false, NSError(domain: "PicSea", code: -1, userInfo: [NSLocalizedDescriptionKey: "Album not found"]))
            return
        }
        guard !assets.isEmpty else { completion(true, nil); return }

        PHPhotoLibrary.shared().performChanges({
            if let change = PHAssetCollectionChangeRequest(for: album) {
                change.addAssets(assets as NSArray)
            }
        }) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }

    func saveResultsToAlbum(named name: String, completion: @escaping (Bool, Error?) -> Void) {
        let assetsToSave: [PHAsset] = self.assets

        createAlbumIfNeeded(named: name) { albumId, err in
            guard let albumId = albumId, err == nil else {
                completion(false, err)
                return
            }
            self.addAssets(assetsToSave, toAlbumId: albumId, completion: completion)
        }
    }

    func addShownAssets(toAlbumWithLocalId localId: String, completion: @escaping (Bool, Error?) -> Void) {
        let fetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localId], options: nil)
        guard let album = fetch.firstObject else {
            completion(false, NSError(domain: "PicSea", code: -1, userInfo: [NSLocalizedDescriptionKey: "Album not found"]))
            return
        }

        let assetsToAdd: [PHAsset] = (self.value(forKey: "shownAssets") as? [PHAsset]) ?? self.assets
        guard !assetsToAdd.isEmpty else { completion(true, nil); return }

        PHPhotoLibrary.shared().performChanges({
            if let change = PHAssetCollectionChangeRequest(for: album) {
                change.addAssets(assetsToAdd as NSArray)
            }
        }) { success, error in
            DispatchQueue.main.async { completion(success, error) }
        }
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}

// MARK: - Search + AI Classification
extension PhotoLibraryViewModel {

    @MainActor
    func runAIClassification() async -> [PHAsset] {
        return await classifier.classify(assets: assets)
    }

    @MainActor
    func search(in assets: [PHAsset], prompt: String) async -> [PHAsset] {
        let keyword = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return allAssets           // empty prompt → show all
        }
        
        if keyword.isEmpty {
            isFilteredResults = false
            return allAssets
        } else {
            isFilteredResults = true
        }
        
        var filteredAssets: [PHAsset] = assets

        
        // Optional: year filtering
        if let year = Int(keyword), keyword.count == 4 {
            filteredAssets = filteredAssets.filter { asset in
                if let date = asset.creationDate {
                    return Calendar.current.component(.year, from: date) == year
                }
                return false
            }
        }
        
        // Run classifier
        let results = await classifier.classify(assets: filteredAssets)
        return results
    }

    func requestThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 256, height: 256),
                contentMode: .aspectFill,
                options: nil
            ) { img, _ in
                continuation.resume(returning: img)
            }
        }
    }
    
    func resetAssets() {
        assets = allAssets
    }

}
