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
    func search(prompt: String) -> [PHAsset] {
        let lower = prompt.lowercased()
        let yearMatch = lower.range(of: #"\b(19|20)\d{2}\b"#, options: .regularExpression)
        if yearMatch != nil {
            return assets.filter { asset in
                guard let d = asset.creationDate else { return false }
                let y = Calendar.current.component(.year, from: d)
                return lower.contains("\(y)")
            }
        } else {
            return Array(assets.prefix(200))
        }
    }
}
