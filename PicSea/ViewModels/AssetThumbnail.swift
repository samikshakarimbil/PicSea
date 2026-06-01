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
    @State private var imageTask: Task<Void, Never>?

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
            imageTask?.cancel()
            imageTask = nil
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

        imageTask?.cancel()
        imageTask = Task {
            let thumbnail = await PhotoLibraryManager.requestThumbnail(for: asset, targetSize: targetSize)

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self.image = thumbnail
            }
        }
    }
}
