import Foundation

struct PiRuntimeInstallation: Equatable {
    enum Source: String {
        case bundled
        case userUpdated
    }

    let source: Source
    let root: URL
    let nodePath: URL
    let npmPath: URL?
    let cliPath: URL
    let authStoragePath: URL
    let version: String

    var displayName: String {
        switch source {
        case .bundled: return "Bundled pi \(version)"
        case .userUpdated: return "Updated pi \(version)"
        }
    }
}

struct PiRuntimeUpdateResult {
    let installed: Bool
    let version: String
    let message: String
}

final class PiRuntimeManager {
    static let packageName = "@mariozechner/pi-coding-agent"
    static let packageRegistryURL = URL(string: "https://registry.npmjs.org/@mariozechner%2Fpi-coding-agent/latest")!

    private let fileManager = FileManager.default

    private var bundledRuntimeRoot: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("pi-runtime", isDirectory: true)
    }

    private var applicationSupportRoot: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("PiChat", isDirectory: true)
            .appendingPathComponent("pi-runtime", isDirectory: true)
    }

    private var currentRuntimeRoot: URL {
        applicationSupportRoot.appendingPathComponent("current", isDirectory: true)
    }

    private var versionsRoot: URL {
        applicationSupportRoot.appendingPathComponent("versions", isDirectory: true)
    }

    func activeRuntime() -> PiRuntimeInstallation? {
        let bundled = bundledRuntimeRoot.flatMap { runtimeInstallation(at: $0, source: .bundled, nodeProvider: nil) }
        let updated = runtimeInstallation(at: currentRuntimeRoot, source: .userUpdated, nodeProvider: bundled)

        switch (updated, bundled) {
        case let (u?, b?):
            return isVersion(u.version, greaterThanOrEqualTo: b.version) ? u : b
        case let (u?, nil):
            return u
        case let (nil, b?):
            return b
        default:
            return nil
        }
    }

    func bundledRuntime() -> PiRuntimeInstallation? {
        bundledRuntimeRoot.flatMap { runtimeInstallation(at: $0, source: .bundled, nodeProvider: nil) }
    }

    func updatedRuntime() -> PiRuntimeInstallation? {
        let bundled = bundledRuntime()
        return runtimeInstallation(at: currentRuntimeRoot, source: .userUpdated, nodeProvider: bundled)
    }

    func latestAvailableVersion() async throws -> String {
        var request = URLRequest(url: Self.packageRegistryURL)
        request.setValue("PiChat", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let latest = try JSONDecoder().decode(NpmLatestPackage.self, from: data)
        return latest.version
    }

    func installLatestIfNeeded() async throws -> PiRuntimeUpdateResult {
        let latest = try await latestAvailableVersion()
        let current = activeRuntime()

        if let current, !isVersion(latest, greaterThan: current.version) {
            return PiRuntimeUpdateResult(
                installed: false,
                version: current.version,
                message: "pi runtime is already up to date (\(current.version))"
            )
        }

        let installed = try await installPackage(version: latest)
        return PiRuntimeUpdateResult(
            installed: true,
            version: installed.version,
            message: "Installed pi runtime \(installed.version)"
        )
    }

    func installPackage(version: String) async throws -> PiRuntimeInstallation {
        guard let nodeHost = bundledRuntime() else {
            throw PiRuntimeError.missingBundledRuntime("Bundled pi runtime with Node/npm is required to auto-update pi.")
        }
        guard let npmPath = nodeHost.npmPath else {
            throw PiRuntimeError.missingBundledRuntime("Bundled npm was not found at Contents/Resources/pi-runtime/node/bin/npm.")
        }

        try fileManager.createDirectory(at: applicationSupportRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: versionsRoot, withIntermediateDirectories: true)

        let safeVersion = version.replacingOccurrences(of: "/", with: "-")
        let staging = applicationSupportRoot.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        let versionRoot = versionsRoot.appendingPathComponent(safeVersion, isDirectory: true)
        let logURL = applicationSupportRoot.appendingPathComponent("npm-install-\(safeVersion).log")

        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)

        do {
            let args = [
                "install",
                "--prefix", staging.path,
                "--omit=dev",
                "--ignore-scripts",
                "--no-audit",
                "--no-fund",
                "--registry=https://registry.npmjs.org",
                "\(Self.packageName)@\(version)"
            ]
            try await runProcess(executable: npmPath, arguments: args, workingDirectory: staging, logURL: logURL, nodeHost: nodeHost)

            let metadata = RuntimeMetadata(package: Self.packageName, version: version)
            let metadataData = try JSONEncoder.pretty.encode(metadata)
            try metadataData.write(to: staging.appendingPathComponent("pichat-runtime.json"), options: .atomic)

            guard let installed = runtimeInstallation(at: staging, source: .userUpdated, nodeProvider: nodeHost), installed.version == version else {
                throw PiRuntimeError.invalidRuntime("Installed pi runtime did not validate after npm install.")
            }

            try? fileManager.removeItem(at: versionRoot)
            try fileManager.moveItem(at: staging, to: versionRoot)
            try? fileManager.removeItem(at: currentRuntimeRoot)
            try fileManager.createSymbolicLink(at: currentRuntimeRoot, withDestinationURL: versionRoot)

            guard let current = runtimeInstallation(at: currentRuntimeRoot, source: .userUpdated, nodeProvider: nodeHost) else {
                throw PiRuntimeError.invalidRuntime("Installed pi runtime could not be activated.")
            }
            return current
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    func shouldRunAutomaticCheck(now: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "pi.runtime.autoUpdatesEnabled") as? Bool ?? true else { return false }
        let last = defaults.object(forKey: "pi.runtime.lastAutoUpdateCheck") as? Date
        guard let last else { return true }
        return now.timeIntervalSince(last) >= 24 * 60 * 60
    }

    func markAutomaticCheck(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: "pi.runtime.lastAutoUpdateCheck")
    }

    private func runtimeInstallation(at root: URL, source: PiRuntimeInstallation.Source, nodeProvider: PiRuntimeInstallation?) -> PiRuntimeInstallation? {
        let packageRoot = root
            .appendingPathComponent("node_modules", isDirectory: true)
            .appendingPathComponent("@mariozechner", isDirectory: true)
            .appendingPathComponent("pi-coding-agent", isDirectory: true)
        let cliPath = packageRoot.appendingPathComponent("dist/cli.js")
        let authStoragePath = packageRoot.appendingPathComponent("dist/core/auth-storage.js")

        guard fileManager.fileExists(atPath: cliPath.path), fileManager.fileExists(atPath: authStoragePath.path) else {
            return nil
        }

        let localNodePath = root.appendingPathComponent("node/bin/node")
        let localNpmPath = root.appendingPathComponent("node/bin/npm")
        let nodePath: URL
        let npmPath: URL?

        if fileManager.isExecutableFile(atPath: localNodePath.path) {
            nodePath = localNodePath
            npmPath = fileManager.isExecutableFile(atPath: localNpmPath.path) ? localNpmPath : nil
        } else if let nodeProvider {
            nodePath = nodeProvider.nodePath
            npmPath = nodeProvider.npmPath
        } else {
            return nil
        }

        let version = readPackageVersion(packageRoot: packageRoot) ?? readRuntimeMetadata(root: root)?.version ?? "unknown"
        return PiRuntimeInstallation(
            source: source,
            root: root,
            nodePath: nodePath,
            npmPath: npmPath,
            cliPath: cliPath,
            authStoragePath: authStoragePath,
            version: version
        )
    }

    private func readPackageVersion(packageRoot: URL) -> String? {
        let packageJSON = packageRoot.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: packageJSON),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = obj["version"] as? String,
              !version.isEmpty else { return nil }
        return version
    }

    private func readRuntimeMetadata(root: URL) -> RuntimeMetadata? {
        let url = root.appendingPathComponent("pichat-runtime.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RuntimeMetadata.self, from: data)
    }

    private func runProcess(executable: URL, arguments: [String], workingDirectory: URL, logURL: URL, nodeHost: PiRuntimeInstallation) async throws {
        fileManager.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)
        defer { try? logHandle.close() }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = logHandle
        process.standardError = logHandle

        var env = ProcessInfo.processInfo.environment
        let nodeBin = nodeHost.nodePath.deletingLastPathComponent().path
        let existingPath = env["PATH"] ?? ""
        env["PATH"] = ([nodeBin, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"] + existingPath.split(separator: ":").map(String.init))
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { parts, item in if !parts.contains(item) { parts.append(item) } }
            .joined(separator: ":")
        process.environment = env

        let status = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }

        if status != 0 {
            let logText = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            let tail = String(logText.suffix(4_000))
            throw PiRuntimeError.installFailed("npm install failed with exit code \(status).\n\(tail)")
        }
    }

    private func isVersion(_ lhs: String, greaterThan rhs: String) -> Bool {
        compareVersions(lhs, rhs) == .orderedDescending
    }

    private func isVersion(_ lhs: String, greaterThanOrEqualTo rhs: String) -> Bool {
        let result = compareVersions(lhs, rhs)
        return result == .orderedDescending || result == .orderedSame
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0.split(separator: "-").first ?? "") ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0.split(separator: "-").first ?? "") ?? 0 }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l > r { return .orderedDescending }
            if l < r { return .orderedAscending }
        }
        return .orderedSame
    }
}

private struct NpmLatestPackage: Decodable {
    let version: String
}

private struct RuntimeMetadata: Codable {
    let package: String
    let version: String
}

private enum PiRuntimeError: LocalizedError {
    case missingBundledRuntime(String)
    case invalidRuntime(String)
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingBundledRuntime(let message), .invalidRuntime(let message), .installFailed(let message):
            return message
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
