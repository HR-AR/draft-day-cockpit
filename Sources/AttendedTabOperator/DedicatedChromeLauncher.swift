import AppKit
import ApplicationServices
import Foundation

enum DedicatedChromeLaunchError: Error, LocalizedError, Equatable {
    case invalidProfileDirectory(String)
    case invalidProfileRoot(String)
    case unsafeArguments
    case chromeUnavailable
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProfileDirectory:
            return "Dedicated YFF Chrome requires its internal Profile 1 directory"
        case .invalidProfileRoot:
            return "Dedicated YFF Chrome requires the ~/.yff-chrome user-data directory"
        case .unsafeArguments:
            return "Dedicated YFF Chrome launch arguments crossed the fixed attended-browser contract"
        case .chromeUnavailable:
            return "Google Chrome is not installed"
        case .launchFailed(let reason):
            return "Dedicated YFF Chrome did not open: \(reason)"
        }
    }
}

struct DedicatedChromeLaunchPlan: Equatable {
    static let chromeBundleIdentifier = "com.google.Chrome"
    static let profileDirectory = "Profile 1"
    static let mockLobbyURL = "https://football.fantasysports.yahoo.com/f1/mock_lobby"
    static let forbiddenArguments = [
        "--disable-extensions", "--load-extension", "--remote-debugging-port",
        "--remote-debugging-pipe", "--headless", "--disable-web-security",
    ]

    let arguments: [String]

    init(userDataDirectory: URL, profileDirectory: String = Self.profileDirectory) throws {
        guard profileDirectory == Self.profileDirectory else {
            throw DedicatedChromeLaunchError.invalidProfileDirectory(profileDirectory)
        }
        let root = userDataDirectory.standardizedFileURL
        guard root.isFileURL, root.lastPathComponent == ".yff-chrome" else {
            throw DedicatedChromeLaunchError.invalidProfileRoot(root.path)
        }
        let arguments = [
            "--user-data-dir=\(root.path)",
            "--profile-directory=\(profileDirectory)",
            "--no-first-run",
            "--no-default-browser-check",
            Self.mockLobbyURL,
        ]
        guard Self.isExactContract(arguments, userDataDirectory: root) else {
            throw DedicatedChromeLaunchError.unsafeArguments
        }
        self.arguments = arguments
    }

    static func isExactContract(_ arguments: [String], userDataDirectory: URL) -> Bool {
        let expected = [
            "--user-data-dir=\(userDataDirectory.standardizedFileURL.path)",
            "--profile-directory=\(profileDirectory)",
            "--no-first-run",
            "--no-default-browser-check",
            mockLobbyURL,
        ]
        guard arguments == expected else { return false }
        return !arguments.contains { argument in
            forbiddenArguments.contains { forbidden in
                argument == forbidden || argument.hasPrefix("\(forbidden)=")
            }
        } && !arguments.contains(where: { $0.contains("login.yahoo.com") })
    }

    static func processCommandUsesExactProfile(_ command: String, userDataDirectory: URL) -> Bool {
        occurrences(of: "--user-data-dir=", in: command) == 1 &&
            occurrences(of: "--profile-directory=", in: command) == 1 &&
            containsExactProcessArgument("--user-data-dir=\(userDataDirectory.standardizedFileURL.path)", in: command) &&
            containsExactProcessArgument("--profile-directory=\(profileDirectory)", in: command) &&
            !forbiddenArguments.contains(where: { command.contains($0) }) &&
            !command.contains("login.yahoo.com")
    }

    static func processOwnsExactProfile(_ pid: pid_t, command: String, userDataDirectory: URL,
                                        singletonLockTarget: String) -> Bool {
        guard let separator = singletonLockTarget.lastIndex(of: "-"),
              separator > singletonLockTarget.startIndex,
              separator < singletonLockTarget.index(before: singletonLockTarget.endIndex),
              let ownerPID = pid_t(singletonLockTarget[singletonLockTarget.index(after: separator)...]),
              ownerPID == pid else { return false }
        return processCommandUsesExactProfile(command, userDataDirectory: userDataDirectory)
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        var count = 0
        var search = text.startIndex..<text.endIndex
        while let range = text.range(of: needle, range: search) {
            count += 1
            guard range.upperBound < text.endIndex else { break }
            search = range.upperBound..<text.endIndex
        }
        return count
    }

    private static func containsExactProcessArgument(_ argument: String, in command: String) -> Bool {
        var search = command.startIndex..<command.endIndex
        while let range = command.range(of: argument, range: search) {
            let beginsAtBoundary = range.lowerBound == command.startIndex ||
                command[command.index(before: range.lowerBound)].isWhitespace
            let endsAtBoundary = range.upperBound == command.endIndex || command[range.upperBound].isWhitespace
            if beginsAtBoundary && endsAtBoundary { return true }
            guard range.upperBound < command.endIndex else { return false }
            search = range.upperBound..<command.endIndex
        }
        return false
    }
}

struct DedicatedChromeLaunchReceipt: Equatable {
    let processIdentifier: Int32?
}

@MainActor
protocol DedicatedChromeLaunching {
    func launch() async throws -> DedicatedChromeLaunchReceipt
}

@MainActor
protocol DedicatedChromeRunningApplication: AnyObject {
    var processIdentifier: pid_t { get }
    var isTerminated: Bool { get }
    @discardableResult func activate(options: NSApplication.ActivationOptions) -> Bool
}

extension NSRunningApplication: DedicatedChromeRunningApplication {}

@MainActor
final class DedicatedChromeLauncher: DedicatedChromeLaunching {
    private let workspace: NSWorkspace
    private let userDataDirectory: URL
    private let applicationURL: () -> URL?
    private let runningApplications: () -> [any DedicatedChromeRunningApplication]
    private let matchesDedicatedProfile: (pid_t, URL) -> Bool
    private let hasOpenWindows: (pid_t) -> Bool
    private let openApplication: (URL, NSWorkspace.OpenConfiguration) async throws -> (any DedicatedChromeRunningApplication)?
    private var launchedApplication: (any DedicatedChromeRunningApplication)?

    init(workspace: NSWorkspace = .shared,
         userDataDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".yff-chrome", isDirectory: true),
         applicationURL: (() -> URL?)? = nil,
         runningApplications: (() -> [any DedicatedChromeRunningApplication])? = nil,
         matchesDedicatedProfile: ((pid_t, URL) -> Bool)? = nil,
         hasOpenWindows: ((pid_t) -> Bool)? = nil,
         openApplication: ((URL, NSWorkspace.OpenConfiguration) async throws ->
            (any DedicatedChromeRunningApplication)?)? = nil) {
        self.workspace = workspace
        self.userDataDirectory = userDataDirectory
        self.applicationURL = applicationURL ?? {
            workspace.urlForApplication(withBundleIdentifier: DedicatedChromeLaunchPlan.chromeBundleIdentifier)
        }
        self.runningApplications = runningApplications ?? {
            workspace.runningApplications.compactMap { application in
                guard application.bundleIdentifier == DedicatedChromeLaunchPlan.chromeBundleIdentifier else {
                    return nil
                }
                return application
            }
        }
        self.matchesDedicatedProfile = matchesDedicatedProfile ?? Self.processUsesDedicatedProfile
        self.hasOpenWindows = hasOpenWindows ?? Self.processHasOpenWindows
        self.openApplication = openApplication ?? { url, configuration in
            try await withCheckedThrowingContinuation { continuation in
                workspace.openApplication(at: url, configuration: configuration) { application, error in
                    if let error {
                        continuation.resume(throwing: DedicatedChromeLaunchError.launchFailed(error.localizedDescription))
                        return
                    }
                    continuation.resume(returning: application)
                }
            }
        }
    }

    private static func processUsesDedicatedProfile(_ pid: pid_t, root: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", String(pid), "-o", "command="]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }
        guard process.terminationStatus == 0,
              let command = String(data: output.fileHandleForReading.readDataToEndOfFile(),
                                   encoding: .utf8) else { return false }
        let lock = root.appendingPathComponent("SingletonLock").path
        guard let lockTarget = try? FileManager.default.destinationOfSymbolicLink(atPath: lock) else { return false }
        return DedicatedChromeLaunchPlan.processOwnsExactProfile(
            pid, command: command, userDataDirectory: root, singletonLockTarget: lockTarget
        )
    }

    private static func processHasOpenWindows(_ pid: pid_t) -> Bool {
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return false }
        return !windows.isEmpty
    }

    private func openChrome(_ chrome: URL, plan: DedicatedChromeLaunchPlan,
                            createsNewApplicationInstance: Bool) async throws -> DedicatedChromeLaunchReceipt {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = plan.arguments
        configuration.activates = true
        configuration.createsNewApplicationInstance = createsNewApplicationInstance
        let application = try await openApplication(chrome, configuration)
        launchedApplication = application
        return DedicatedChromeLaunchReceipt(processIdentifier: application?.processIdentifier)
    }

    func launch() async throws -> DedicatedChromeLaunchReceipt {
        if let launchedApplication, !launchedApplication.isTerminated,
           hasOpenWindows(launchedApplication.processIdentifier) {
            launchedApplication.activate(options: [.activateAllWindows])
            return DedicatedChromeLaunchReceipt(processIdentifier: launchedApplication.processIdentifier)
        }
        launchedApplication = nil
        if let existing = runningApplications().first(where: {
            !$0.isTerminated && matchesDedicatedProfile($0.processIdentifier, userDataDirectory)
        }) {
            if !hasOpenWindows(existing.processIdentifier) {
                let plan = try DedicatedChromeLaunchPlan(userDataDirectory: userDataDirectory)
                guard let chrome = applicationURL() else { throw DedicatedChromeLaunchError.chromeUnavailable }
                return try await openChrome(chrome, plan: plan, createsNewApplicationInstance: false)
            }
            launchedApplication = existing
            existing.activate(options: [.activateAllWindows])
            return DedicatedChromeLaunchReceipt(processIdentifier: existing.processIdentifier)
        }
        let plan = try DedicatedChromeLaunchPlan(userDataDirectory: userDataDirectory)
        guard let chrome = applicationURL() else {
            throw DedicatedChromeLaunchError.chromeUnavailable
        }
        return try await openChrome(chrome, plan: plan, createsNewApplicationInstance: true)
    }
}

enum DedicatedChromeLaunchStatus: Equatable {
    case idle
    case opening
    case requested(processIdentifier: Int32?)
    case refused(String)

    var permitsLaunchRequest: Bool {
        self != .opening
    }

    var compactLabel: String {
        switch self {
        case .idle: return "YFF Chrome ready"
        case .opening: return "YFF Chrome opening"
        case .requested(let pid): return pid.map { "YFF Chrome pid \($0)" } ?? "YFF Chrome requested"
        case .refused: return "YFF Chrome refused"
        }
    }
}
