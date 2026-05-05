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

        guard !cleanedText.isEmpty else {
            return query
        }

        let words = cleanedText
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        // Media type detection
        if words.contains("screenshot") || words.contains("screenshots") {
            query.mediaType = .screenshot
        } else if words.contains("selfie") || words.contains("selfies") {
            query.mediaType = .selfie
        } else if words.contains("photo") || words.contains("photos") {
            query.mediaType = .photo
        }

        // Simple blur detection
        if words.contains("blurry") || words.contains("blurred") {
            query.includeBlurred = true
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
            "from", "in", "of", "with", "and", "my",
            "screenshot", "screenshots", "selfie", "selfies",
            "blurry", "blurred"
        ]

        query.concepts = words.filter { word in
            !ignoredWords.contains(word) &&
            !(word.count == 4 && Int(word) != nil)
        }

        return query
    }
}
