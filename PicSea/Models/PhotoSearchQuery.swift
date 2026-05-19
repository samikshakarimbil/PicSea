//
//  PhotoSearchQuery.swift
//  PicSea
//

import Foundation

struct PhotoSearchQuery {
    var originalText: String = ""
    var concepts: [String] = []

    var startDate: Date?
    var endDate: Date?

    var includeBlurred: Bool = true
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
