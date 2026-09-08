import Foundation
import os

public enum AppGroup {

    /// The suffix that survives rewriting. Sideloadly / AltStore prefix the
    /// group with an account-unique token, so the tail stays intact.
    private static let expectedSuffix = "com.hmatt1.shortcutlauncherwidget"

    /// Optional build-time override. Set `APP_GROUP_ID` in Info.plist (fed by
    /// an .xcconfig) when you build and sign yourself.
    private static let infoPlistKey = "APP_GROUP_ID"

    private static let log = Logger(subsystem: "com.hmatt1.launcherboard", category: "AppGroup")

    /// The resolved, entitled app group identifier, or nil if none is usable.
    public static let identifier: String? = resolve()

    public static var containerURL: URL? {
        guard let identifier else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static var defaults: UserDefaults? {
        guard let identifier else { return nil }
        return UserDefaults(suiteName: identifier)
    }

    // MARK: - Resolution

    private static func resolve() -> String? {
        var candidates: [String] = []

        if let override = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String,
           !override.isEmpty {
            candidates.append(override)
        }

        candidates.append("group." + expectedSuffix)

        let provisioned = provisionedAppGroups()
        candidates.append(contentsOf: provisioned.filter { $0.hasSuffix(expectedSuffix) })
        candidates.append(contentsOf: provisioned)

        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            if isUsable(candidate) {
                log.info("Resolved app group: \(candidate, privacy: .public)")
                return candidate
            }
        }

        log.error("No usable app group. Profile listed: \(provisioned, privacy: .public)")
        return nil
    }

    private static func isUsable(_ group: String) -> Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil
    }

    // MARK: - Provisioning profile parsing

    /// App groups declared in this bundle's provisioning profile. In an app
    /// extension, `Bundle.main` is the .appex, which carries its own profile.
    public static func provisionedAppGroups() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let plist = embeddedPlist(in: data),
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else {
            return []
        }
        return groups
    }

    /// `embedded.mobileprovision` is a CMS-signed blob with an XML plist in the
    /// middle. Slice out the plist by its delimiters and parse that.
    private static func embeddedPlist(in data: Data) -> [String: Any]? {
        let openTag = Data("<plist".utf8)
        let closeTag = Data("</plist>".utf8)

        guard let start = data.range(of: openTag)?.lowerBound,
              let end = data.range(of: closeTag, options: .backwards)?.upperBound,
              start < end
        else {
            return nil
        }

        let slice = Data(data[start..<end])
        let parsed = try? PropertyListSerialization.propertyList(from: slice, options: [], format: nil)
        return parsed as? [String: Any]
    }
}
