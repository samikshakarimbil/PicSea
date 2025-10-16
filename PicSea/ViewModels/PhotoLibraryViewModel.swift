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
        let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
        var temp: [PHAsset] = []
        allPhotos.enumerateObjects { asset, _, _ in
            temp.append(asset)
        }
        DispatchQueue.main.async {
            self.assets = temp
        }
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

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
