//
//  PhotoAssetGrid.swift
//  PicSea
//

import SwiftUI

struct PhotoAssetGrid: View {
    let assetIDs: [String]
    var isSelectionMode = false
    var selectedAssetIDs: Set<String> = []
    var onToggleSelection: (String) -> Void = { _ in }
    var onInteractionChanged: (Bool) -> Void = { _ in }

    private let columnCount = 3

    var body: some View {
        GeometryReader { proxy in
            let cellSize = floor(proxy.size.width / CGFloat(columnCount))
            let columns = Array(
                repeating: GridItem(.fixed(cellSize), spacing: 0),
                count: columnCount
            )

            ScrollView {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(assetIDs, id: \.self) { assetID in
                        SelectableAssetThumbnail(
                            assetIdentifier: assetID,
                            size: cellSize,
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedAssetIDs.contains(assetID)
                        ) {
                            onToggleSelection(assetID)
                        }
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in onInteractionChanged(true) }
                    .onEnded { _ in onInteractionChanged(false) }
            )
        }
    }
}
