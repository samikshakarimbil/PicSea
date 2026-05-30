//
//  AssetThumbnail.swift
//  PicSea
//

import SwiftUI
import Photos
import UIKit

struct AssetThumbnail: View {
    let assetIdentifier: String
    let size: CGFloat

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    init(assetIdentifier: String, size: CGFloat) {
        self.assetIdentifier = assetIdentifier
        self.size = size
    }

    init(asset: PHAsset, size: CGFloat) {
        self.assetIdentifier = asset.localIdentifier
        self.size = size
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .onAppear {
            requestImage()
        }
        .onDisappear {
            if let requestID {
                PHImageManager.default().cancelImageRequest(requestID)
            }

            requestID = nil
            image = nil
        }
    }

    private func requestImage() {
        guard image == nil,
              size > 1,
              let asset = PhotoLibraryManager.asset(for: assetIdentifier) else {
            return
        }

        let targetSize = CGSize(
            width: size * UIScreen.main.scale,
            height: size * UIScreen.main.scale
        )

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            self.image = image
        }
    }
}
