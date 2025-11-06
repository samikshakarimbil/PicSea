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
