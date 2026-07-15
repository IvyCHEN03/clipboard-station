import XCTest
@testable import ClipboardStation

final class PasteboardContentClassifierTests: XCTestCase {
    func testRecognizesTabDelimitedSpreadsheetRows() {
        let text = """
        Name\tScore\tNote
        Ada\t98\tGreat
        Linus\t95\tKernel
        """

        XCTAssertTrue(PasteboardContentClassifier.looksLikeSpreadsheet(text))
    }

    func testRecognizesSingleRowCopiedFromSpreadsheet() {
        XCTAssertTrue(PasteboardContentClassifier.looksLikeSpreadsheet("Ada\t98\tGreat"))
    }

    func testRecognizesConservativeCsvTable() {
        let text = """
        Name,Score,Note
        Ada,98,Great
        Linus,95,Kernel
        """

        XCTAssertTrue(PasteboardContentClassifier.looksLikeSpreadsheet(text))
    }

    func testDoesNotTreatTwoCommaSeparatedSentencesAsSpreadsheet() {
        let text = """
        hello, world
        copied, text
        """

        XCTAssertFalse(PasteboardContentClassifier.looksLikeSpreadsheet(text))
    }

    func testDoesNotTreatPlainMultilineTextAsSpreadsheet() {
        let text = """
        Please summarize this paragraph.
        It has multiple lines but no table structure.
        """

        XCTAssertFalse(PasteboardContentClassifier.looksLikeSpreadsheet(text))
    }
}
