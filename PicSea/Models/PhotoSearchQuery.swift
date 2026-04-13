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

    var includeBlurred: Bool = false
    var mediaType: MediaType = .any
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
