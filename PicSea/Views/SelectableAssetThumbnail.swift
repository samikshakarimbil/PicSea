//
//  SelectableAssetThumbnail.swift
//  PicSea
//

import SwiftUI
import Photos

struct SelectableAssetThumbnail: View {
    let assetIdentifier: String
    let size: CGFloat
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void

    init(assetIdentifier: String,
         size: CGFloat,
         isSelectionMode: Bool,
         isSelected: Bool,
         onTap: @escaping () -> Void) {
        self.assetIdentifier = assetIdentifier
        self.size = size
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self.onTap = onTap
    }

    init(asset: PHAsset,
         size: CGFloat,
         isSelectionMode: Bool,
         isSelected: Bool,
         onTap: @escaping () -> Void) {
        self.init(
            assetIdentifier: asset.localIdentifier,
            size: size,
            isSelectionMode: isSelectionMode,
            isSelected: isSelected,
            onTap: onTap
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AssetThumbnail(assetIdentifier: assetIdentifier, size: size)
                .overlay {
                    if isSelectionMode {
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 4)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }

            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .padding(6)
                    .foregroundStyle(isSelected ? .blue : .white)
                    .shadow(radius: 2)
            }
        }
    }
}
