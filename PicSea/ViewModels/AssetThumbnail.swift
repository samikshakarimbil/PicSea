//
//  AssetThumbnail.swift
//  PicSea
//

import SwiftUI
import Photos
import UIKit

struct AssetThumbnail: View {
    let asset: PHAsset
    let size: CGFloat

    @State private var image: UIImage?

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
    }

    private func requestImage() {
        let targetSize = CGSize(
            width: size * UIScreen.main.scale,
            height: size * UIScreen.main.scale
        )

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        ) { image, _ in
            self.image = image
        }
    }
}
