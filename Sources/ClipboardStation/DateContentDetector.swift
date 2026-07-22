import Foundation

struct DetectedDateContent: Equatable {
    let date: Date
    let timeZone: TimeZone?
    let matchedText: String
}

enum DateContentDetector {
    static func firstDate(in text: String) -> DetectedDateContent? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, options: [], range: range),
              let date = match.date,
              let matchRange = Range(match.range, in: text) else {
            return nil
        }
        return DetectedDateContent(
            date: date,
            timeZone: match.timeZone,
            matchedText: String(text[matchRange])
        )
    }
}
