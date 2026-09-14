import XCTest
@testable import LauncherBoard

/// `LauncherIntent.capped(_:at:)` - the generic the real `slots` property
/// calls (see Shared/LauncherIntent.swift for why it's generic rather than
/// tested with a real `[SystemShortcut]`).
final class LauncherIntentTests: XCTestCase {
    func testNilInputReturnsEmptyArray() {
        XCTAssertEqual(LauncherIntent.capped(Optional<[Int]>.none, at: 5), [])
    }

    func testEmptyInputReturnsEmptyArray() {
        XCTAssertEqual(LauncherIntent.capped([Int](), at: 5), [])
    }

    func testUnderLimitReturnsEverythingUnchanged() {
        XCTAssertEqual(LauncherIntent.capped([1, 2, 3], at: 5), [1, 2, 3])
    }

    func testExactlyAtLimitReturnsEverythingUnchanged() {
        XCTAssertEqual(LauncherIntent.capped([1, 2, 3, 4, 5], at: 5), [1, 2, 3, 4, 5])
    }

    func testOverLimitTruncatesToTheFirstNInOrder() {
        XCTAssertEqual(LauncherIntent.capped([1, 2, 3, 4, 5, 6, 7], at: 5), [1, 2, 3, 4, 5])
    }

    func testWorksForNonIntElementTypesToo() {
        XCTAssertEqual(LauncherIntent.capped(["a", "b", "c", "d"], at: 2), ["a", "b"])
    }

    func testMatchesTheRealMaxSlotsCapUsedByLauncherIntentSlots() {
        let names = (0..<(BoardGrid.maxSlots + 20)).map { "shortcut-\($0)" }
        let capped = LauncherIntent.capped(names, at: BoardGrid.maxSlots)
        XCTAssertEqual(capped.count, BoardGrid.maxSlots)
        XCTAssertEqual(capped, Array(names.prefix(BoardGrid.maxSlots)))
    }
}
