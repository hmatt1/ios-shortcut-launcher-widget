import XCTest

/// The position arithmetic behind Move Preset / Move Theme, checked against the
/// real `Array.move(fromOffsets:toOffset:)` the stores' `reorder` uses.
final class ListOrderTests: XCTestCase {

    private func moved(_ items: [String], from index: Int, toPosition position: Int) -> [String] {
        var result = items
        let final = ListOrder.finalIndex(forPosition: position, count: items.count)
        result.move(fromOffsets: IndexSet(integer: index), toOffset: ListOrder.moveDestination(from: index, toFinalIndex: final))
        return result
    }

    private let items = ["a", "b", "c", "d", "e"]

    func testMovingUpLandsAtThePosition() {
        XCTAssertEqual(moved(items, from: 3, toPosition: 1), ["d", "a", "b", "c", "e"])
        XCTAssertEqual(moved(items, from: 4, toPosition: 2), ["a", "e", "b", "c", "d"])
    }

    func testMovingDownLandsAtThePosition() {
        XCTAssertEqual(moved(items, from: 0, toPosition: 3), ["b", "c", "a", "d", "e"])
        XCTAssertEqual(moved(items, from: 1, toPosition: 5), ["a", "c", "d", "e", "b"])
    }

    func testMovingToItsOwnPositionChangesNothing() {
        for index in items.indices {
            XCTAssertEqual(moved(items, from: index, toPosition: index + 1), items)
        }
    }

    func testPositionsAreClampedIntoTheList() {
        XCTAssertEqual(moved(items, from: 2, toPosition: 0), ["c", "a", "b", "d", "e"])
        XCTAssertEqual(moved(items, from: 2, toPosition: -5), ["c", "a", "b", "d", "e"])
        XCTAssertEqual(moved(items, from: 2, toPosition: 99), ["a", "b", "d", "e", "c"])
    }

    func testEveryStartAndEndPositionLandsExactly() {
        for from in items.indices {
            for position in 1...items.count {
                let result = moved(items, from: from, toPosition: position)
                XCTAssertEqual(result.firstIndex(of: items[from]), position - 1, "from \(from) to \(position)")
                XCTAssertEqual(Set(result), Set(items))
            }
        }
    }

    func testASingleItemListStaysPut() {
        XCTAssertEqual(moved(["only"], from: 0, toPosition: 5), ["only"])
    }
}
