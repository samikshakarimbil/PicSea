//
//  PhotoSearchQuery.swift
//  PicSea
//

import Foundation

struct PhotoSearchQuery {
    var originalText: String = ""
    var normalizedText: String = ""
    var searchTokens: [String] = []
    var concepts: [String] = []

    var startDate: Date?
    var endDate: Date?

    var includeBlurred: Bool = true
    var onlyBlurry: Bool = false
    var duplicateFilter: DuplicateFilter = .exclude
    var mediaType: MediaType = .any
}

enum DuplicateFilter: String, CaseIterable, Identifiable {
    case include
    case exclude
    case onlyDuplicates

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .include: return "Yes"
        case .exclude: return "No"
        case .onlyDuplicates: return "Only show duplicates"
        }
    }
}

enum DuplicateSimilaritySensitivity: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var hashDistanceThreshold: Int {
        switch self {
        case .low: return 18
        case .medium: return 12
        case .high: return 7
        }
    }

    var visionMinimumSimilarity: Float {
        switch self {
        case .low: return 0.72
        case .medium: return 0.8
        case .high: return 0.88
        }
    }
}

enum MediaType: String, CaseIterable, Identifiable {
    case any
    case photo
    case screenshot
    case selfie

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .any: return "Any"
        case .photo: return "Photos"
        case .screenshot: return "Screenshots"
        case .selfie: return "Selfies"
        }
    }
}
