import XCTest
import WidgetKit
@testable import LauncherBoard

/// Direct regression coverage for the exact bug class that caused the XL
/// widget crash: a wrong `WidgetFamily` -> `BoardSize` mapping.
///
/// `LauncherProvider.placeholder(in:)` / `.snapshot(for:in:)` /
/// `.timeline(for:in:)` are NOT tested here, on purpose, not by oversight:
/// they all require a real `WidgetKit.TimelineProviderContext`
/// ("Context"), which has no public initializer - a longstanding, still-
/// unresolved WidgetKit limitation (see Apple Developer Forums thread
/// 672442: "timelineProvider code cannot be unit tested because Context
/// can't even be created", unanswered as of this writing). Everything those
/// three methods actually DO beyond that unconstructible parameter is build
/// a `LauncherEntry` from a `LauncherIntent` - which IS directly
/// constructible - and that's exactly the path `RenderSmokeTests.swift`
/// exercises instead, by constructing `LauncherEntry`/`LauncherWidgetView`
/// directly and forcing a real render, bypassing `Context` entirely.
final class WidgetProviderTests: XCTestCase {
    /// Every `WidgetFamily` case WidgetKit currently defines - not just the
    /// four `.supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
    /// .systemExtraLargePortrait])` declares in Widget/Widget.swift - maps
    /// to a sane `BoardSize` and never crashes. Pins the two cases that were
    /// actually at issue: `.systemExtraLargePortrait` (iOS 27's real "fills
    /// a Home Screen page" iPhone family, and the fix) must map to
    /// `.extraLarge`; `.systemExtraLarge` (the original iPad/Mac-landscape-
    /// only family this widget never actually offers, and the wrong case
    /// the crash traced back to) must fall through to `.large` via the
    /// `default:` branch, exactly like every other unsupported family, and
    /// must NOT silently start mapping to `.extraLarge` too - that would
    /// reintroduce ambiguity between two different WidgetFamily cases
    /// resolving to the same BoardSize for different reasons.
    func testEveryWidgetFamilyMapsToASaneBoardSize() {
        // WidgetFamily isn't CaseIterable (confirmed via a real CI compile
        // error: "type 'WidgetFamily' has no member 'allCases'") - Apple
        // adds new families across OS versions without guaranteeing an
        // enumerable list, which is exactly why BoardSize(family:) has a
        // `default:` branch at all. Every case that exists as of this
        // writing is listed explicitly instead.
        let everyKnownFamily: [WidgetFamily] = [
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ]
        for family in everyKnownFamily {
            let size = BoardSize(family: family)
            XCTAssertTrue(BoardSize.allCases.contains(size), "BoardSize(family: \(family)) produced \(size), not a real case")
        }
    }

    func testExtraLargePortraitMapsToExtraLarge() {
        XCTAssertEqual(BoardSize(family: .systemExtraLargePortrait), .extraLarge)
    }

    func testPlainExtraLargeFallsThroughToLargeNotExtraLarge() {
        // .systemExtraLarge is the iPad/Mac-landscape-only family (iOS 15+)
        // this widget has never actually offered on the iPhone Home Screen -
        // it must keep falling through to the `default:` branch (.large),
        // not `.extraLarge`, or the two families become indistinguishable.
        XCTAssertEqual(BoardSize(family: .systemExtraLarge), .large)
    }

    func testDeclaredSupportedFamiliesAllMapCorrectly() {
        // The exact families Widget/Widget.swift's `.supportedFamilies(...)`
        // declares - if this list and the mapping above ever drift apart,
        // that's exactly how a size silently becomes unreachable or wrong.
        let declaredSupportedFamilies: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait]
        let expected: [WidgetFamily: BoardSize] = [
            .systemSmall: .small,
            .systemMedium: .medium,
            .systemLarge: .large,
            .systemExtraLargePortrait: .extraLarge,
        ]
        for family in declaredSupportedFamilies {
            XCTAssertEqual(BoardSize(family: family), expected[family])
        }
    }
}
