import Foundation

enum RangeSelectionDirection: Equatable {
    case up
    case down
}

enum RangeSelection {
    static func direction(
        from anchorID: UUID,
        to targetID: UUID,
        in orderedIDs: [UUID]
    ) -> RangeSelectionDirection? {
        guard let anchorIndex = orderedIDs.firstIndex(of: anchorID),
              let targetIndex = orderedIDs.firstIndex(of: targetID),
              anchorIndex != targetIndex else {
            return nil
        }
        return targetIndex < anchorIndex ? .up : .down
    }

    static func ids(
        from anchorID: UUID,
        to targetID: UUID,
        in orderedIDs: [UUID]
    ) -> Set<UUID> {
        guard let anchorIndex = orderedIDs.firstIndex(of: anchorID),
              let targetIndex = orderedIDs.firstIndex(of: targetID) else {
            return []
        }
        let lowerBound = min(anchorIndex, targetIndex)
        let upperBound = max(anchorIndex, targetIndex)
        return Set(orderedIDs[lowerBound...upperBound])
    }
}
