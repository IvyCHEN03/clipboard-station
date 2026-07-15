import Foundation

enum PasteboardContentClassifier {
    static func looksLikeSpreadsheet(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            return false
        }

        if lines.contains(where: { $0.contains("\t") }) {
            return looksLikeDelimitedRows(lines, delimiter: "\t", minimumRows: 1, minimumColumns: 2)
        }

        guard lines.count >= 2,
              lines.allSatisfy({ $0.contains(",") }) else {
            return false
        }

        return looksLikeDelimitedRows(lines, delimiter: ",", minimumRows: 3, minimumColumns: 2)
            || looksLikeDelimitedRows(lines, delimiter: ",", minimumRows: 2, minimumColumns: 3)
    }

    private static func looksLikeDelimitedRows(
        _ lines: [String],
        delimiter: Character,
        minimumRows: Int,
        minimumColumns: Int
    ) -> Bool {
        guard lines.count >= minimumRows else {
            return false
        }
        let columnCounts = lines.map {
            $0.split(separator: delimiter, omittingEmptySubsequences: false).count
        }
        guard let firstCount = columnCounts.first,
              firstCount >= minimumColumns else {
            return false
        }
        return columnCounts.allSatisfy { $0 == firstCount }
    }
}
