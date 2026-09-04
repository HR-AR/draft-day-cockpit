import AppKit
import XCTest
@testable import AttendedTabOperator

@MainActor
private final class FakeChromeApplication: DedicatedChromeRunningApplication {
    let processIdentifier: pid_t
    var isTerminated = false
    private(set) var activations: [NSApplication.ActivationOptions] = []

    init(processIdentifier: pid_t) {
        self.processIdentifier = processIdentifier
    }

    func activate(options: NSApplication.ActivationOptions) -> Bool {
        activations.append(options)
        return true
    }
}

@MainActor
final class DedicatedChromeLauncherTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/Users/example/.yff-chrome", isDirectory: true)
    private let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")

    func testCompletedRequestStillPermitsLifecycleRevalidation() {
        XCTAssertFalse(DedicatedChromeLaunchStatus.opening.permitsLaunchRequest)
        XCTAssertTrue(DedicatedChromeLaunchStatus.requested(processIdentifier: 4242).permitsLaunchRequest)
        XCTAssertTrue(DedicatedChromeLaunchStatus.refused("invented failure").permitsLaunchRequest)
    }

    func testRepeatLaunchReactivatesWithoutOpeningAnotherLobby() async throws {
        let application = FakeChromeApplication(processIdentifier: 4242)
        var configurations: [NSWorkspace.OpenConfiguration] = []
        let launcher = DedicatedChromeLauncher(
            userDataDirectory: root,
            applicationURL: { self.chrome },
            hasOpenWindows: { _ in true },
            openApplication: { _, configuration in
                configurations.append(configuration)
                return application
            }
        )

        _ = try await launcher.launch()
        _ = try await launcher.launch()

        XCTAssertEqual(configurations.count, 1)
        XCTAssertEqual(application.activations, [[.activateAllWindows]])
    }

    func testTerminatedProcessCanColdStartAgain() async throws {
        let first = FakeChromeApplication(processIdentifier: 4242)
        let second = FakeChromeApplication(processIdentifier: 4343)
        var applications = [first, second]
        var openCount = 0
        let launcher = DedicatedChromeLauncher(
            userDataDirectory: root,
            applicationURL: { self.chrome },
            hasOpenWindows: { _ in true },
            openApplication: { _, _ in
                openCount += 1
                return applications.removeFirst()
            }
        )

        _ = try await launcher.launch()
        first.isTerminated = true
        _ = try await launcher.launch()

        XCTAssertEqual(openCount, 2)
    }

    func testPlanRefusesAnotherProfileAndDangerousFlags() throws {
        XCTAssertThrowsError(try DedicatedChromeLaunchPlan(userDataDirectory: root,
                                                            profileDirectory: "Default"))
        let safe = try DedicatedChromeLaunchPlan(userDataDirectory: root).arguments
        XCTAssertFalse(DedicatedChromeLaunchPlan.isExactContract(
            safe + ["--remote-debugging-port=9222"], userDataDirectory: root
        ))
    }
}
