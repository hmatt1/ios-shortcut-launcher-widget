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
}
