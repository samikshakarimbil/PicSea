//
//  PromptParser.swift
//  PicSea
//

import Foundation
import NaturalLanguage

struct PromptParser {
    func parse(_ text: String) -> PhotoSearchQuery {
        var query = PhotoSearchQuery()
        query.originalText = text

        let cleanedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        query.normalizedText = cleanedText

        guard !cleanedText.isEmpty else {
            return query
        }

        let extractedKeywords = extractKeywords(from: cleanedText)
        let words = extractedKeywords.isEmpty
            ? cleanedText.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            : extractedKeywords

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

        let searchableTokens = normalizeKeywords(words).filter { word in
            !ignoredWords.contains(word) &&
            !(word.count == 4 && Int(word) != nil) &&
            word.count > 1
        }
        let expandedSearchableTokens = expandSearchTokens(searchableTokens)
        query.searchTokens = expandedSearchableTokens
        query.concepts = expandedSearchableTokens

        return query
    }

    private func extractKeywords(from text: String) -> [String] {
        var keywords: [String] = []
        keywords.append(contentsOf: quotedPhrases(in: text))
        keywords.append(contentsOf: lexicalKeywords(in: text))
        return keywords
    }

    private func quotedPhrases(in text: String) -> [String] {
        let pattern = #""([^"]+)""#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let phraseRange = Range(match.range(at: 1), in: text) else {
                return nil
            }

            return String(text[phraseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func lexicalKeywords(in text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        let range = text.startIndex..<text.endIndex
        var keywords: [String] = []

        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .omitOther]
        ) { tag, tokenRange in
            guard let tag else {
                return true
            }

            let token = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard shouldKeep(token: token, tag: tag) else {
                return true
            }

            keywords.append(token)
            return true
        }

        return keywords
    }

    private func shouldKeep(token: String, tag: NLTag) -> Bool {
        switch tag {
        case .noun, .personalName, .adjective:
            return token.count > 1
        case .verb:
            return token.count > 2
        default:
            return false
        }
    }

    private func normalizeKeywords(_ keywords: [String]) -> [String] {
        var normalized: [String] = []
        var seen = Set<String>()

        for keyword in keywords {
            let cleanedParts = keyword
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }

            guard !cleanedParts.isEmpty else {
                continue
            }

            let phrase = cleanedParts.joined(separator: " ")
            if seen.insert(phrase).inserted {
                normalized.append(phrase)
            }

            if cleanedParts.count == 1 {
                let word = cleanedParts[0]
                if let singular = singularWordVariant(from: word),
                   seen.insert(singular).inserted {
                    normalized.append(singular)
                }

                if let plural = pluralWordVariant(from: word),
                   seen.insert(plural).inserted {
                    normalized.append(plural)
                }
            }
        }

        return normalized
    }

    private func singularWordVariant(from word: String) -> String? {
        guard word.count > 2 else { return nil }

        if word.hasSuffix("ies"), word.count > 3 {
            return String(word.dropLast(3)) + "y"
        }

        if word.hasSuffix("sses") || word.hasSuffix("xes") || word.hasSuffix("zes") || word.hasSuffix("ches") || word.hasSuffix("shes") || word.hasSuffix("oes") {
            return String(word.dropLast(2))
        }

        if word.hasSuffix("s"), !word.hasSuffix("ss") {
            return String(word.dropLast())
        }

        return nil
    }

    private func pluralWordVariant(from word: String) -> String? {
        guard word.count > 1 else { return nil }

        if word.hasSuffix("y"), word.count > 1 {
            let stem = String(word.dropLast())
            if let precedingCharacter = stem.last, !"aeiou".contains(precedingCharacter) {
                return stem + "ies"
            }
        }

        if word.hasSuffix("s") || word.hasSuffix("x") || word.hasSuffix("z") || word.hasSuffix("ch") || word.hasSuffix("sh") {
            return word + "es"
        }

        if word.hasSuffix("ss") {
            return word + "es"
        }

        return word + "s"
    }

    private func expandSearchTokens(_ tokens: [String]) -> [String] {
        var expanded: [String] = []
        var seen = Set<String>()

        for token in tokens {
            for candidate in [token] + semanticSearchTerms(for: token) {
                let normalizedCandidate = candidate.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedCandidate.isEmpty else { continue }

                if seen.insert(normalizedCandidate).inserted {
                    expanded.append(normalizedCandidate)
                }
            }
        }

        return expanded
    }

    private func semanticSearchTerms(for token: String) -> [String] {
        switch token {
        case "dress", "dresses":
            return [
                "gown", "gowns",
                "skirt", "skirts",
                "outfit", "outfits",
                "clothing",
                "apparel",
                "fashion",
                "formalwear",
                "eveningwear"
            ]
        default:
            return []
        }
    }
}
