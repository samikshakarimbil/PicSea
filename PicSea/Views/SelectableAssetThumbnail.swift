//
//  SelectableAssetThumbnail.swift
//  PicSea
//

import SwiftUI
import Photos

struct SelectableAssetThumbnail: View {
    let asset: PHAsset
    let size: CGFloat
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AssetThumbnail(asset: asset, size: size)
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
