import CryptoKit
import Foundation
import MacToolsCore

private enum UpdateError: LocalizedError {
    case failed(String)
    var errorDescription: String? { if case .failed(let message) = self { return message }; return nil }
}

@main
struct MacToolsUpdater {
    static func main() async {
        do { try await update(checkOnly: CommandLine.arguments.contains("--check")) }
        catch {
            fputs("macTools-Update: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func update(checkOnly: Bool) async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let app = home.appendingPathComponent("Applications/macTools.app")
        let info = try appInfo(app)
        let lock = home.appendingPathComponent("Library/Application Support/macTools/Update.lock")
        try FileManager.default.createDirectory(at: lock.deletingLastPathComponent(), withIntermediateDirectories: true)
        // flock is released by the OS even if an update process is terminated.
        let descriptor = open(lock.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw UpdateError.failed("Update-Sperre konnte nicht geöffnet werden.") }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { print("Ein Update läuft bereits."); return }

        let session = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 45
            config.timeoutIntervalForResource = 600
            return config
        }())
        let endpoint = URL(string: "https://api.github.com/repos/JustJustin64x/macTools/releases/latest")!
        let metadata = try await fetch(endpoint, session: session, accept: "application/vnd.github+json")
        let release = try JSONDecoder().decode(UpdateRelease.self, from: metadata)
        guard let commit = release.commit,
              let archiveURL = release.assetURL(named: "macTools.zip"),
              let checksumURL = release.assetURL(named: "SHA256SUMS") else {
            throw UpdateError.failed("Die neueste Veröffentlichung enthält kein gültiges macTools-App-Paket.")
        }
        if info["MacToolsCommit"] as? String == commit {
            print("macTools ist auf dem neuesten Stand.")
            return
        }
        if checkOnly { print("Update verfügbar: \(release.tag_name)"); return }

        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("macTools-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let checksums = String(decoding: try await fetch(checksumURL, session: session), as: UTF8.self)
        guard let expected = UpdateRelease.expectedSHA256(checksums, filename: "macTools.zip") else {
            throw UpdateError.failed("Die SHA-256-Prüfsumme fehlt.")
        }
        let archive = temp.appendingPathComponent("macTools.zip")
        let (download, response) = try await session.download(for: request(archiveURL))
        try validate(response)
        try FileManager.default.moveItem(at: download, to: archive)
        let contents = try Data(contentsOf: archive, options: .mappedIfSafe)
        let actual = SHA256.hash(data: contents).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw UpdateError.failed("Prüfsumme stimmt nicht. Das Update wurde verworfen.") }
        let listing = try run("/usr/bin/unzip", ["-Z1", archive.path])
        guard UpdateRelease.archivePathsAreSafe(listing) else { throw UpdateError.failed("Ungültige Pfade im App-Archiv.") }
        let detailedListing = try run("/usr/bin/unzip", ["-Z", "-l", archive.path])
        guard !detailedListing.split(separator: "\n").contains(where: { $0.first == "l" }) else {
            throw UpdateError.failed("Symbolische Verknüpfungen im Update-Archiv sind nicht erlaubt.")
        }
        let expanded = temp.appendingPathComponent("expanded")
        try FileManager.default.createDirectory(at: expanded, withIntermediateDirectories: true)
        _ = try run("/usr/bin/ditto", ["-x", "-k", archive.path, expanded.path])
        let incoming = expanded.appendingPathComponent("macTools.app")
        let incomingInfo = try appInfo(incoming)
        guard incomingInfo["CFBundleIdentifier"] as? String == "io.github.justjustin64x.macTools",
              incomingInfo["MacToolsCommit"] as? String == commit else {
            throw UpdateError.failed("App-Kennung oder Quellversion stimmt nicht mit der Veröffentlichung überein.")
        }
        let incomingEpoch = (incomingInfo["MacToolsSourceEpoch"] as? NSNumber)?.int64Value ?? 0
        let installedEpoch = (info["MacToolsSourceEpoch"] as? NSNumber)?.int64Value ?? 0
        guard incomingEpoch > installedEpoch else {
            print("Die installierte lokale Version ist gleich neu oder neuer; kein Downgrade.")
            return
        }
        _ = try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", incoming.path])
        let installer = incoming.appendingPathComponent("Contents/Resources/install-app.sh")
        _ = try run("/bin/bash", [installer.path, incoming.path])
        print("macTools wurde automatisch aktualisiert.")
    }

    private static func appInfo(_ app: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw UpdateError.failed("App-Metadaten konnten nicht gelesen werden.")
        }
        return info
    }

    private static func request(_ url: URL, accept: String = "application/octet-stream") -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("macTools-Updater", forHTTPHeaderField: "User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        return request
    }

    private static func fetch(_ url: URL, session: URLSession, accept: String = "application/octet-stream") async throws -> Data {
        let (data, response) = try await session.data(for: request(url, accept: accept))
        try validate(response)
        return data
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.failed("GitHub konnte nicht erreicht werden (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)).")
        }
    }

    private static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard task.terminationStatus == 0 else { throw UpdateError.failed(output) }
        return output
    }
}
