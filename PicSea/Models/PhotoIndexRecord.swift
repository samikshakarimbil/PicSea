//
//  PhotoIndexRecord.swift
//  PicSea
//

import Foundation
import SwiftData

@Model
final class PhotoIndexRecord {
    @Attribute(.unique) var assetLocalIdentifier: String
    var creationDate: Date?
    var pixelWidth: Int
    var pixelHeight: Int
    var mediaTypeRawValue: Int
    var mediaSubtypesRawValue: Int
    var isScreenshot: Bool
    var isSelfie: Bool
    var blurScore: Float?
    var perceptualHash: String?
    var duplicateGroupID: String?
    var duplicateScore: Float?
    var indexingStatus: String
    var lastIndexedAt: Date?
    var indexVersion: Int
    var cameraRollIndex: Int
    var visionLabelsText: String = ""
    var visionLabelsWithConfidenceText: String = ""
    var visionIndexedAt: Date?
    var visionIndexVersion: Int = 0

    init(assetLocalIdentifier: String,
         creationDate: Date?,
         pixelWidth: Int,
         pixelHeight: Int,
         mediaTypeRawValue: Int,
         mediaSubtypesRawValue: Int,
         isScreenshot: Bool,
         isSelfie: Bool,
         indexingStatus: PhotoIndexingStatus = .pending,
         indexVersion: Int,
         cameraRollIndex: Int) {
        self.assetLocalIdentifier = assetLocalIdentifier
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.mediaTypeRawValue = mediaTypeRawValue
        self.mediaSubtypesRawValue = mediaSubtypesRawValue
        self.isScreenshot = isScreenshot
        self.isSelfie = isSelfie
        self.blurScore = nil
        self.perceptualHash = nil
        self.duplicateGroupID = nil
        self.duplicateScore = nil
        self.indexingStatus = indexingStatus.rawValue
        self.lastIndexedAt = nil
        self.indexVersion = indexVersion
        self.cameraRollIndex = cameraRollIndex
        self.visionLabelsText = ""
        self.visionLabelsWithConfidenceText = ""
        self.visionIndexedAt = nil
        self.visionIndexVersion = 0
    }
}

enum PhotoIndexingStatus: String {
    case pending
    case indexed
    case failed
}
