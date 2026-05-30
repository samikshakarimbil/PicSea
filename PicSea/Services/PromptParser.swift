//
//  PromptParser.swift
//  PicSea
//

import Foundation

struct PromptParser {
    func parse(_ text: String) -> PhotoSearchQuery {
        var query = PhotoSearchQuery()
        query.originalText = text

        let cleanedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        query.normalizedText = cleanedText

        guard !cleanedText.isEmpty else {
            return query
        }

        let words = cleanedText
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        // Media type detection
        if words.contains("screenshot") || words.contains("screenshots") {
            query.mediaType = .screenshot
        } else if words.contains("selfie") || words.contains("selfies") {
            query.mediaType = .selfie
        } else if words.contains("photo") || words.contains("photos") {
            query.mediaType = .photo
        }

        // Simple blur detection
        if words.contains("blurry") || words.contains("blurred") || words.contains("bad") {
            query.includeBlurred = true
            query.onlyBlurry = true
        }

        if words.contains("duplicate") ||
            words.contains("duplicates") ||
            words.contains("duplicated") ||
            words.contains("similar") {
            query.duplicateFilter = .onlyDuplicates
        }

        // Year detection
        if let yearWord = words.first(where: { $0.count == 4 && Int($0) != nil }),
           let year = Int(yearWord) {
            var components = DateComponents()
            components.year = year
            components.month = 1
            components.day = 1

            let calendar = Calendar.current
            query.startDate = calendar.date(from: components)

            var endComponents = DateComponents()
            endComponents.year = year
            endComponents.month = 12
            endComponents.day = 31
            query.endDate = calendar.date(from: endComponents)
        }

        let ignoredWords: Set<String> = [
            "show", "me", "find", "photos", "photo", "pictures", "pics",
            "from", "in", "of", "with", "and", "my", "a", "an", "the",
            "screenshot", "screenshots", "selfie", "selfies",
            "blurry", "blurred", "bad", "duplicate", "duplicates", "duplicated", "similar"
        ]

        let searchableTokens = words.filter { word in
            !ignoredWords.contains(word) &&
            !(word.count == 4 && Int(word) != nil) &&
            word.count > 1
        }
        query.searchTokens = searchableTokens
        query.concepts = searchableTokens

        return query
    }
}
