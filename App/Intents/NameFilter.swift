import Foundation

/// The name match shared by the "Find Presets" / "Find Themes" actions and the
/// entity pickers' search, so the two can't drift apart. Pure, so it can be
/// unit-tested (an `AppIntent` can't be constructed outside the system).
enum NameFilter {
    /// `items` whose name contains `text`, in their original order. A nil, empty
    /// or whitespace-only `text` matches everything. Matching ignores case and
    /// diacritics (`localizedStandardContains`, the rule Finder-style search
    /// uses), so "ember" finds "Ember" and "cafe" finds "Café".
    static func matching<T>(_ items: [T], name: (T) -> String, containing text: String?) -> [T] {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return items
        }
        return items.filter { name($0).localizedStandardContains(trimmed) }
    }

    /// The first item whose name equals `text` (ignoring case and surrounding
    /// whitespace), used by "Reuse Existing". Nil when there is none or `text`
    /// is blank.
    static func first<T>(_ items: [T], name: (T) -> String, named text: String) -> T? {
        let wanted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return nil }
        return items.first {
            name($0).trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(wanted) == .orderedSame
        }
    }
}
