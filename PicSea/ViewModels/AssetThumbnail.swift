//
//  AssetThumbnail.swift
//  PicSea
//
//  Created by Samiksha Karimbil on 11/5/25.
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
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .onAppear(perform: requestImage)
    }

    private func requestImage() {
        let target = CGSize(width: size * UIScreen.main.scale, height: size * UIScreen.main.scale)
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFill,
            options: nil
        ) { img, _ in
            self.image = img
        }
    }
}
