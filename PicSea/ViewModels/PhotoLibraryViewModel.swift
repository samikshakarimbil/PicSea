//
//  PhotoLibraryViewModel.swift
//  PicSea
//

import Foundation
import SwiftUI
import Photos

class PhotoLibraryViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published var assets: [PHAsset] = []
    @Published var authorized: Bool = false

    override init() {
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
        DispatchQueue.main.async { self.assets = temp }
    }


    // MARK: - Live updates

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            self.fetchPhotos()
        }
    }
    
    // Get an existing album by name (if it exists)
    func fetchAlbum(named name: String) -> PHAssetCollection? {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "localizedTitle = %@", name)
        let res = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: opts)
        return res.firstObject
    }

    // Create the album if needed and return its localIdentifier
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

    // Add the current results (your filtered list) to an album by id
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

    // Public method you call from the button
    func saveResultsToAlbum(named name: String, completion: @escaping (Bool, Error?) -> Void) {
        // Use your filtered list if you have one; otherwise use `assets`
        // If you created `shownAssets`, swap it in here.
        let assetsToSave: [PHAsset] = self.assets

        createAlbumIfNeeded(named: name) { albumId, err in
            guard let albumId = albumId, err == nil else {
                completion(false, err)
                return
            }
            self.addAssets(assetsToSave, toAlbumId: albumId, completion: completion)
        }
    }

    // Add the currently displayed results to the given album (by local id)
    func addShownAssets(toAlbumWithLocalId localId: String, completion: @escaping (Bool, Error?) -> Void) {
        let fetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localId], options: nil)
        guard let album = fetch.firstObject else {
            completion(false, NSError(domain: "PicSea", code: -1, userInfo: [NSLocalizedDescriptionKey: "Album not found"]))
            return
        }
        // Use shownAssets if you have it; if not, use assets (your current array)
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
    // MARK: - Folder / Album Creation
extension PhotoLibraryViewModel {
    // Fake search: if prompt contains a 4-digit year, filter by that year. Otherwise show first 200 items.
    @MainActor
    func search(prompt: String) async -> [PHAsset] {
        let keyword = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return assets }

        var matches: [PHAsset] = []

        for asset in assets {
            // Step 1: get image for asset (thumbnail is fine)
            let img = await requestThumbnail(for: asset)
            guard let img = img else { continue }

            // Step 2: run Vision classifier
            do {
                let labels = try await VisionClassifier.classify(image: img)

                // Step 3: check if the prompt is one of the labels
                if labels.contains(keyword) {
                    matches.append(asset)
                }
            } catch {
                print("Vision failed:", error)
            }
        }

        return matches
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

}
