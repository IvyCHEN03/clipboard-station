import Foundation

enum TagNormalization {
    static let customTagMaximumLength = 10

    static func normalized(_ rawValue: String, maximumLength: Int? = nil) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }
        if let maximumLength, value.count > maximumLength {
            return nil
        }
        return value
    }

    static func canonicalKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func unique(
        _ values: [String],
        maximumLength: Int? = nil
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for rawValue in values {
            guard let value = normalized(rawValue, maximumLength: maximumLength) else {
                continue
            }
            let key = canonicalKey(value)
            guard seen.insert(key).inserted else {
                continue
            }
            result.append(value)
        }
        return result
    }

    static func mergedStable(_ groups: [String]...) -> [String] {
        unique(groups.flatMap { $0 })
    }
}
