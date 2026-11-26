import Foundation

public struct UpdateRelease: Decodable, Sendable {
    public struct Asset: Decodable, Sendable {
        public let name: String
        public let browser_download_url: URL
    }
    public let tag_name: String
    public let draft: Bool
    public let prerelease: Bool
    public let assets: [Asset]

    public var commit: String? {
        guard tag_name.hasPrefix("build-") else { return nil }
        let value = String(tag_name.dropFirst(6))
        guard value.count == 40, value.allSatisfy({ $0.isHexDigit }) else { return nil }
        return value.lowercased()
    }

    public func assetURL(named name: String) -> URL? {
        guard !draft, !prerelease, commit != nil,
              let asset = assets.first(where: { $0.name == name }),
              asset.browser_download_url.scheme == "https",
              asset.browser_download_url.host == "github.com",
              asset.browser_download_url.path == "/JustJustin64x/macTools/releases/download/\(tag_name)/\(name)" else { return nil }
        return asset.browser_download_url
    }

    public static func expectedSHA256(_ checksums: String, filename: String) -> String? {
        for line in checksums.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, parts[1] == Substring(filename), parts[0].count == 64,
                  parts[0].allSatisfy({ $0.isHexDigit }) else { continue }
            return parts[0].lowercased()
        }
        return nil
    }

    public static func archivePathsAreSafe(_ listing: String) -> Bool {
        let paths = listing.split(separator: "\n")
        return !paths.isEmpty && paths.allSatisfy {
            $0.hasPrefix("macTools.app/") && !$0.split(separator: "/").contains("..") && !$0.contains("\\")
        }
    }
}
