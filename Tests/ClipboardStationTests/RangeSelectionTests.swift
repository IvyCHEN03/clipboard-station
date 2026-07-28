import XCTest
@testable import ClipboardStation

final class RangeSelectionTests: XCTestCase {
    func testDirectionFollowsDisplayedOrder() {
        let ids = (0..<5).map { _ in UUID() }

        XCTAssertEqual(RangeSelection.direction(from: ids[3], to: ids[1], in: ids), .up)
        XCTAssertEqual(RangeSelection.direction(from: ids[1], to: ids[4], in: ids), .down)
        XCTAssertNil(RangeSelection.direction(from: ids[2], to: ids[2], in: ids))
    }

    func testRangeIncludesBothEndpointsAndMiddleItems() {
        let ids = (0..<6).map { _ in UUID() }

        XCTAssertEqual(
            RangeSelection.ids(from: ids[4], to: ids[1], in: ids),
            Set(ids[1...4])
        )
    }

    func testMissingEndpointReturnsEmptyRange() {
        let ids = (0..<3).map { _ in UUID() }

        XCTAssertTrue(
            RangeSelection.ids(from: ids[0], to: UUID(), in: ids).isEmpty
        )
    }
}
