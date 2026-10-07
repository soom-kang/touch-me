import Foundation
import Combine
import ServiceManagement

private enum LoginLaunchMessage {
    case none, installationRequired, registrationFailed
    case changeFailed(String)

    var text: String {
        switch self {
        case .none: return ""
        case .installationRequired:
            return Texts.get("Touch Me를 Applications에 복사한 뒤 로그인 시작을 설정하세요.",
                             "Copy Touch Me to Applications before enabling launch at login.")
        case .registrationFailed:
            return Texts.get("로그인 시작이 등록되지 않았습니다. 시스템 설정에서 확인하세요.",
                             "Launch at login was not registered. Check System Settings.")
        case .changeFailed(let detail):
            return Texts.get("로그인 시작 설정을 변경하지 못했습니다: ",
                             "Could not change launch at login: ") + detail
        }
    }
}

final class LoginLaunchModel: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var requiresApproval = false
    @Published private var messageState: LoginLaunchMessage = .none
    var message: String { messageState.text }

    var installed: Bool {
        let bundle = Bundle.main.bundleURL.standardizedFileURL
        let parent = bundle.deletingLastPathComponent().path
        let userApplications = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications").path
        return bundle.pathExtension.lowercased() == "app"
            && (parent == "/Applications" || parent == userApplications)
    }

    init() { refresh() }

    func refresh() {
        let status = SMAppService.mainApp.status
        enabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ requested: Bool) {
        messageState = .none
        guard !requested || installed else {
            messageState = .installationRequired
            return
        }
        do {
            if requested {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
            refresh()
            if requested && !enabled {
                messageState = .registrationFailed
            }
        } catch {
            refresh()
            messageState = .changeFailed(error.localizedDescription)
        }
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
