import AppKit
import Foundation
import TouchMePlatform

struct ScanEvidence: Codable {
    let schemaVersion: Int
    let mode: String
    let queryReturnedSet: Bool
    let devices: [DeviceEvidence]
    let activeDisplayCount: Int
    let eligibleExternalDisplayCount: Int
    let permissionsOfThisProcess: PermissionState
}

if CommandLine.arguments.dropFirst().contains("--scan") {
    let scan = HIDDiscovery.scan()
    let displays = DisplayDiscovery.scan()
    let evidence = ScanEvidence(schemaVersion: 1, mode: "metadata_only_no_open",
                                queryReturnedSet: scan.queryReturnedSet, devices: scan.evidence,
                                activeDisplayCount: displays.count,
                                eligibleExternalDisplayCount: displays.filter(\.canMap).count,
                                permissionsOfThisProcess: PermissionState.current())
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        let data = try encoder.encode(evidence)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    } catch { exit(1) }
    // Absence is not evidence of unsupported hardware or successful enumeration.
    exit(scan.devices.isEmpty ? 3 : 0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
