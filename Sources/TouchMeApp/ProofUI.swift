import AppKit
import CoreGraphics
import SwiftUI
import Combine
import IOKit.hid
import OSLog
import TouchMePlatform
import TouchMappingCore

enum Texts {
    static var korean: Bool { LanguagePreferences.shared.selected == .korean }
    static func get(_ ko: String, _ en: String) -> String { korean ? ko : en }
    static func error(_ error: ProofError) -> String {
        guard korean else { return error.localizedDescription }
        switch error {
        case .missingPermissions: return "입력 모니터링과 손쉬운 사용 권한을 모두 허용해주세요."
        case .unsupportedDevice: return "USB 장치 구분 또는 absolute X/Y·접촉 요소를 확인하지 못했습니다. 한 대만 연결하고 다시 조회해주세요."
        case .unsupportedDisplay: return "회전·미러링하지 않은 외부 화면을 선택해주세요."
        case .deviceChanged(.touchDeviceRemoval): return "터치 장치 연결이 끊겨 중지했습니다. USB 연결을 확인하고 다시 조회해주세요."
        case .deviceChanged(.displayValidation): return "대상 화면이 변경되었거나 확인되지 않아 중지했습니다. 다시 조회해주세요."
        case .openFailed: return "장치를 점유하지 못했습니다. 권한이나 다른 매핑 앱의 실행 상태를 확인해주세요."
        case .readFailed: return "접촉 상태를 읽지 못해 중지했습니다. 다시 조회해주세요."
        case .eventCreationFailed: return "입력 이벤트를 만들지 못해 중지했습니다."
        case .modeUnsupported: return "확인한 P16KT의 멀티터치 설정 구조와 달라 시작하지 않았습니다."
        case .modeStateUnexpected: return "장치 모드 또는 식별 값이 확인한 시작 상태와 달라 변경하지 않았습니다."
        case .modeReadFailed: return "장치 모드를 읽지 못해 시작하지 않았습니다."
        case .modeWriteFailed: return "멀티터치 모드로 전환하지 못해 시작하지 않았습니다."
        case .modeReadbackMismatch: return "멀티터치 설정을 다시 읽은 결과가 달라 시작하지 않았습니다."
        case .modeRestoreFailed(let result):
            switch UInt32(bitPattern: result) {
            case 0xE0000F01: return "다른 프로세스가 모드 복구를 사용 중입니다. 기록을 보존하고 매핑을 차단했습니다."
            case 0xE0000F02: return "이전 복구 프로세스의 상태를 안전하게 확인하지 못했습니다. 기록을 보존하고 매핑을 차단했습니다."
            case 0xE0000F03: return "모드 복구 기록이 올바르지 않습니다. 추측한 모드를 쓰지 않고 매핑을 차단했습니다."
            case 0xE0000F04: return "복구 기록의 부팅 또는 장치 연결이 현재와 다릅니다. 같은 포트에 재연결해도 자동 원복하지 않습니다."
            case 0xE0000F05: return "현재 장치 모드가 기록된 복구 상태와 달라 원복 값을 쓰지 않았습니다."
            case 0xE0000F06: return "복구 기록이 예상과 다르게 변경되어 보존하고 매핑을 차단했습니다."
            case 0xE0000F07: return "복구 기록을 안전하게 저장하거나 읽지 못했습니다. 기록을 보존하고 매핑을 차단했습니다."
            default: return "원래 장치 모드 복구에 실패했습니다. 현재 연결을 유지한 채 ‘복구 재시도’를 누르세요. 연결이 달라지면 자동 원복하지 않습니다."
            }
        }
    }
}

private enum ProofMessage {
    case none, resumeRequired, mappingActive, startFailed, mappingStopped, environmentStopped
    case mappingSuspended, mappingResuming, resumeTimedOut
    case checkingInterruption, interruptionUnconfirmed(ProofError)
    case failure(ProofError)

    var text: String {
        switch self {
        case .none: return ""
        case .resumeRequired:
            return Texts.get("이전 매핑을 재개하려면 저장한 P16KT·화면 연결과 두 권한이 필요합니다. 연결 후 다시 조회하세요.",
                             "The saved P16KT, display and both permissions are required to resume. Connect them and refresh.")
        case .mappingActive:
            return Texts.get("멀티터치로 동작 중입니다. 중지·정상 종료하면 시작 전 장치 모드로 복구합니다.",
                             "Multitouch is active. Stop or normal quit restores the device mode from before mapping.")
        case .environmentStopped:
            return Texts.get("화면 구성이 변경되어 중지했습니다. 대상과 권한을 확인한 뒤 직접 매핑을 시작하세요.",
                             "Mapping stopped because the display configuration changed. Check the target and permissions, then start mapping manually.")
        case .mappingSuspended:
            return Texts.get("잠금·절전 또는 사용자 전환으로 매핑을 잠시 중지했습니다. 돌아오면 자동으로 재개합니다.",
                             "Mapping is paused while the screen is locked, the Mac is asleep, or another user is active. It will resume when you return.")
        case .mappingResuming:
            return Texts.get("저장한 장치와 화면을 확인하고 있습니다. 준비되면 매핑을 재개합니다.",
                             "Checking the saved device and display. Mapping will resume when they are ready.")
        case .resumeTimedOut:
            return Texts.get("매핑을 자동으로 재개하지 못했습니다. 장치·화면과 권한을 확인한 뒤 직접 시작하세요.",
                             "Mapping could not resume automatically. Check the device, display and permissions, then start it manually.")
        case .checkingInterruption:
            return Texts.get("대상 화면 변화로 입력을 중지했습니다. 잠금·절전 상태를 확인하고 있습니다.",
                             "Input stopped after a target display change. Checking for a lock or sleep interruption.")
        case .interruptionUnconfirmed(let error):
            return Texts.error(error) + Texts.get(" 잠금·절전 중단을 확인하지 못해 자동 재개하지 않았습니다.",
                                                " No lock or sleep interruption was confirmed, so automatic resume was cancelled.") + " [\(error.code)]"
        case .startFailed: return Texts.get("시험을 시작하지 못했습니다.", "The proof could not start.")
        case .mappingStopped: return Texts.get("매핑을 중지했습니다.", "Mapping stopped.")
        case .failure(let error): return Texts.error(error) + " [\(error.code)]"
        }
    }
}

private enum MappingInterruption: Hashable {
    case protectedDataUnavailable, sessionUnavailable, inactiveSession, sleep, displaySleep, screensSleep
}

private struct MappingSettlingContext {
    let savedMapping: SavedMapping
    let display: DisplayTarget
    var deadline: TimeInterval?
}

private struct PendingDisplayInterruption {
    let savedMapping: SavedMapping
    let display: DisplayTarget
    let error: ProofError
    let expiresAt: TimeInterval
}

final class ProofModel: ObservableObject {
    @Published var devices: [TouchDevice] = []
    @Published var displays: [DisplayTarget] = []
    @Published var selectedDevice = ""
    @Published var selectedDisplay: UInt32 = 0
    @Published var permissions = PermissionState.current()
    @Published var running = false
    @Published var modeRestorePending = false
    @Published private(set) var startupRecoveryError: ProofError?
    var startupRecoveryBlocked: Bool { startupRecoveryError != nil }
    @Published var values = 0
    @Published var clicks = 0
    @Published var scrolls = 0
    @Published var maximumContacts = 0
    @Published private var messageState: ProofMessage = .none
    var message: String { messageState.text }
    @Published private var lastFailureState: ProofMessage?
    var lastFailureMessage: String { lastFailureState?.text ?? "" }
    @Published var scanReturnedSet = false
    @Published private var confirmation = TargetConfirmation()
    var targetConfirmed: Bool { confirmation.isConfirmed }
    @Published private(set) var resumePending = false
    let mapper = ProofMapper()
    var onRunChange: ((Bool) -> Void)?
    private var permissionTimer: Timer?
    private var recoveryTimer: Timer?
    private var recoveryActivity: NSObjectProtocol?
    private var startingAutomaticMapping = false
    private let recoveryLog = Logger(subsystem: "io.github.soom-kang.touchme", category: "MappingRecovery")
    private var savedMapping: SavedMapping?
    private var restoreSavedSelection = true
    private var interruptions: Set<MappingInterruption> = []
    private var interruptionResumePending = false {
        didSet { updateRecoveryScheduling() }
    }
    private var recoveryWindow = RecoveryWindow()
    private let uptime: () -> TimeInterval
    private var settlingContext: MappingSettlingContext?
    private var pendingDisplayInterruption: PendingDisplayInterruption? {
        didSet { updateRecoveryScheduling() }
    }
    private var terminating = false

    private var sessionBlocker: MappingReadiness? {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return .sessionUnavailable }
        // Public keys from CoreGraphics/CGSession.h; never read private lock keys.
        return session["kCGSSessionOnConsoleKey"] as? Bool == true
            && session["kCGSessionLoginDoneKey"] as? Bool == true ? nil : .inactiveSession
    }

    private var sessionAvailable: Bool { sessionBlocker == nil }

    init(uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.uptime = uptime
        savedMapping = MappingPreferences.load()
        resumePending = savedMapping?.resumeMapping == true
        mapper.onChange = { [weak self] in
            guard let self else { return }
            self.running = self.mapper.running
            self.modeRestorePending = self.mapper.modeRestorePending
            self.values = self.mapper.receivedValues
            self.clicks = self.mapper.postedDowns
            self.scrolls = self.mapper.postedScrolls
            self.maximumContacts = self.mapper.maximumContacts
            self.updateRecoveryScheduling()
            self.onRunChange?(self.running)
        }
        mapper.onFailure = { [weak self] error, display in
            self?.handleMappingFailure(error, previousDisplay: display)
        }
        mapper.onEnvironmentCheck = { [weak self] in self?.synchronizeAvailability() }
        mapper.onDisplaySleep = { [weak self] in self?.updateInterruption(.displaySleep, present: true) }
        synchronizeAvailability()
        refresh(attemptResume: false)
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.synchronizeDisplayPowerAvailability()
            self.synchronizeAvailability()
            if let deadline = self.settlingContext?.deadline,
               self.uptime() >= deadline, !self.interruptionResumePending {
                self.settlingContext = nil
            }
            let previouslyAllowed = self.permissions.canMap
            self.permissions = PermissionState.current()
            if self.interruptionResumePending {
                self.attemptInterruptedResume()
            } else if !previouslyAllowed && self.permissions.canMap && self.resumePending {
                self.refresh()
            }
        }
        if let permissionTimer { RunLoop.main.add(permissionTimer, forMode: .common) }
    }

    deinit {
        permissionTimer?.invalidate()
        recoveryTimer?.invalidate()
        if let recoveryActivity { ProcessInfo.processInfo.endActivity(recoveryActivity) }
    }

    private func updateRecoveryScheduling() {
        let pending = interruptionResumePending || pendingDisplayInterruption != nil
        let canObserveReturn = !interruptions.contains(.sleep) && !interruptions.contains(.inactiveSession)
        let active = !terminating && (!modeRestorePending || running) && canObserveReturn
            && (pending || startingAutomaticMapping)
        if active, recoveryActivity == nil {
            recoveryActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep, reason: "Restore interrupted touch mapping")
        } else if !active, let recoveryActivity {
            ProcessInfo.processInfo.endActivity(recoveryActivity)
            self.recoveryActivity = nil
        }
        if active && pending && !startingAutomaticMapping {
            guard recoveryTimer == nil else { return }
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.synchronizeDisplayPowerAvailability()
                self.synchronizeAvailability()
                self.attemptInterruptedResume()
            }
            recoveryTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else {
            recoveryTimer?.invalidate()
            recoveryTimer = nil
        }
    }

    var canStart: Bool { readiness.canStart }

    var readiness: MappingReadiness {
        if terminating { return .terminating }
        if running { return .running }
        if modeRestorePending { return .restoreRequired }
        if startupRecoveryBlocked { return .recordedRestoreRequired }
        if pendingDisplayInterruption != nil { return .checkingInterruption }
        if !NSApp.isProtectedDataAvailable || interruptions.contains(.protectedDataUnavailable) {
            return .protectedDataUnavailable
        }
        if let blocker = sessionBlocker { return blocker }
        if interruptions.contains(.sessionUnavailable) { return .sessionUnavailable }
        if interruptions.contains(.inactiveSession) { return .inactiveSession }
        if interruptions.contains(.sleep) { return .sleeping }
        if interruptions.contains(.displaySleep) || interruptions.contains(.screensSleep) { return .displaysSleeping }
        if !permissions.inputMonitoring && !permissions.accessibility { return .permissionsRequired }
        if !permissions.inputMonitoring { return .inputMonitoringRequired }
        if !permissions.accessibility { return .accessibilityRequired }
        if devices.isEmpty { return scanReturnedSet ? .noDevice : .deviceQueryFailed }
        if devices.count > 1 { return .multipleDevices }
        guard let device = devices.first(where: { $0.key == selectedDevice }) else { return .selectDevice }
        if device.vendor != 0x0457 || device.product != 0x0819 { return .unsupportedModel }
        if !device.canMap { return .unverifiedDescriptor }
        if device.locationID == nil { return .missingLocation }
        guard let display = displays.first(where: { $0.id == selectedDisplay }) else { return .selectDisplay }
        if let blocker = MappingReadiness.displayBlocker(display) { return blocker }
        if !targetConfirmed { return .targetConfirmationRequired }
        return .ready
    }

    func refresh(attemptResume: Bool = true) {
        synchronizeAvailability()
        guard pendingDisplayInterruption == nil, !running && !modeRestorePending else { return }
        permissions = PermissionState.current()
        if let error = mapper.stop() {
            startupRecoveryError = error
            recordFailure(.failure(error))
            return
        }
        startupRecoveryError = nil
        confirmation.invalidate()
        let recoveryScanStart = interruptionResumePending ? self.uptime() : nil
        let scan = HIDDiscovery.scan()
        devices = scan.devices
        scanReturnedSet = scan.queryReturnedSet
        displays = DisplayDiscovery.scan()
        if let recoveryScanStart {
            recoveryLog.notice("Readiness scan finished in \(self.uptime() - recoveryScanStart, format: .fixed(precision: 3))s")
        }
        if restoreSavedSelection, let savedMapping {
            let matchingDevices = devices.filter { matches($0, saved: savedMapping) }
            let matchingDisplays = displays.filter { $0.persistentUUID == savedMapping.displayUUID && $0.canMap }
            selectedDevice = matchingDevices.count == 1 ? matchingDevices[0].key : ""
            selectedDisplay = matchingDisplays.count == 1 ? matchingDisplays[0].id : 0
            confirmation.restore(savedTargetMatches: devices.count == 1
                && !selectedDevice.isEmpty && selectedDisplay != 0)
        } else {
            if !devices.contains(where: { $0.key == selectedDevice }) { selectedDevice = devices.first?.key ?? "" }
            if !displays.contains(where: { $0.id == selectedDisplay }) {
                selectedDisplay = displays.first(where: { $0.canMap })?.id ?? 0
            }
        }
        if resumePending {
            messageState = interruptionResumePending
                ? (interruptions.isEmpty ? .mappingResuming : .mappingSuspended) : .resumeRequired
        }
        if attemptResume { resumeSavedMappingIfPossible() }
    }

    func start(automatic: Bool = false) {
        synchronizeAvailability()
        guard canStart, let device = devices.first(where: { $0.key == selectedDevice }),
              let display = displays.first(where: { $0.id == selectedDisplay }),
              let uuid = display.persistentUUID, let location = device.locationID else { return }
        let saved = SavedMapping(displayUUID: uuid, vendor: device.vendor, product: device.product,
                                 locationID: location, resumeMapping: true)
        guard saved.isValid else { return }
        let expectedDisplay = automatic ? settlingContext?.display : nil
        startingAutomaticMapping = automatic
        defer {
            startingAutomaticMapping = false
            updateRecoveryScheduling()
        }
        cancelPendingResume(clearSettling: !automatic)
        do {
            try mapper.start(device: device, display: display, expectedDisplay: expectedDisplay)
            MappingPreferences.save(saved)
            savedMapping = saved
            restoreSavedSelection = true
            confirmation.confirm(true)
            messageState = .mappingActive
            synchronizeAvailability()
        } catch let error as ProofError {
            if case .modeRestoreFailed = error, !mapper.modeRestorePending {
                startupRecoveryError = error
            }
            handleMappingFailure(error)
        } catch {
            rememberStoppedState()
            recordFailure(.startFailed)
        }
    }

    func resumeSavedMappingIfPossible() {
        synchronizeAvailability()
        if interruptionResumePending {
            guard interruptions.isEmpty, recoveryWindow.deadline != nil else { return }
            let now = self.uptime()
            if recoveryWindow.hasExpired(at: now) {
                rememberStoppedState()
                messageState = .resumeTimedOut
                return
            }
            guard now >= recoveryWindow.nextAttempt else { return }
        }
        guard resumePending, let savedMapping, savedMapping.resumeMapping,
              let device = devices.first(where: { $0.key == selectedDevice }),
              matches(device, saved: savedMapping),
              displays.first(where: { $0.id == selectedDisplay })?.persistentUUID == savedMapping.displayUUID,
              canStart else { return }
        if let settlingContext {
            guard let display = displays.first(where: { $0.id == selectedDisplay }),
                  display.matchesConfiguration(of: settlingContext.display) else { return }
        }
        start(automatic: true)
    }

    func synchronizeAvailability() {
        updateInterruption(nil, present: false)
    }

    private var displaySleepState: Bool? {
        let uuid = mapper.activeDisplayTarget?.persistentUUID
            ?? settlingContext?.display.persistentUUID
            ?? pendingDisplayInterruption?.display.persistentUUID
            ?? (resumePending ? savedMapping?.displayUUID : nil)
        guard let uuid else { return nil }
        return DisplayDiscovery.sleepState(for: uuid)
    }

    func synchronizeDisplayPowerAvailability() {
        // An unavailable online query proves neither sleep nor wake.
        guard let asleep = displaySleepState else { return }
        updateInterruption(.displaySleep, present: asleep)
    }

    func setSleeping(_ sleeping: Bool) {
        if sleeping {
            updateInterruption(.sleep, present: true)
        } else {
            updateInterruption(.sleep, present: false, displaySleeping: displaySleepState ?? false)
        }
    }

    func setScreensSleeping(_ sleeping: Bool) {
        if sleeping {
            updateInterruption(.screensSleep, present: true)
        } else {
            // The public wake event is return evidence even if the target is
            // temporarily absent. A verified sleeping target still blocks resume.
            updateInterruption(.screensSleep, present: false, displaySleeping: displaySleepState ?? false)
        }
    }

    func setSessionActive(_ active: Bool) {
        updateInterruption(.inactiveSession, present: !active)
    }

    private func updateInterruption(_ event: MappingInterruption?, present: Bool, displaySleeping: Bool? = nil) {
        guard !terminating else { return }
        defer { updateRecoveryScheduling() }
        expirePendingDisplayInterruption()
        var updated = interruptions
        if let event {
            if present { updated.insert(event) } else { updated.remove(event) }
        }
        if let displaySleeping {
            if displaySleeping { updated.insert(.displaySleep) }
            else { updated.remove(.displaySleep) }
        }
        if NSApp.isProtectedDataAvailable { updated.remove(.protectedDataUnavailable) }
        else { updated.insert(.protectedDataUnavailable) }
        if sessionAvailable { updated.remove(.sessionUnavailable) }
        else { updated.insert(.sessionUnavailable) }
        if !updated.isEmpty, let pendingDisplayInterruption {
            settlingContext = MappingSettlingContext(savedMapping: pendingDisplayInterruption.savedMapping,
                                                     display: pendingDisplayInterruption.display, deadline: nil)
            self.pendingDisplayInterruption = nil
            messageState = .mappingSuspended
        }
        guard updated != interruptions else { return }

        let wasInterrupted = !interruptions.isEmpty
        interruptions = updated
        if !updated.isEmpty {
            if running, let savedMapping, savedMapping.resumeMapping,
               let display = mapper.activeDisplayTarget {
                settlingContext = MappingSettlingContext(savedMapping: savedMapping, display: display, deadline: nil)
            } else if settlingContext != nil {
                settlingContext?.deadline = nil
            }
            interruptionResumePending = interruptionResumePending || running || resumePending
            resumePending = interruptionResumePending && savedMapping?.resumeMapping == true
            recoveryWindow.deadline = nil
            if running, !releaseMapping() {
                rememberStoppedState()
                return
            }
            if resumePending && !modeRestorePending { messageState = .mappingSuspended }
        } else if wasInterrupted && interruptionResumePending && !modeRestorePending {
            let now = self.uptime()
            recoveryWindow.begin(at: now)
            settlingContext?.deadline = recoveryWindow.deadline
            messageState = .mappingResuming
            recoveryLog.notice("Interruption cleared; readiness window started")
        }
    }

    private func attemptInterruptedResume() {
        guard interruptionResumePending, interruptions.isEmpty, !terminating,
              !modeRestorePending, recoveryWindow.deadline != nil else { return }
        let now = self.uptime()
        if recoveryWindow.hasExpired(at: now) {
            rememberStoppedState()
            messageState = .resumeTimedOut
            return
        }
        guard now >= recoveryWindow.nextAttempt else { return }
        recoveryLog.notice("Readiness attempt started")
        refresh()
        if interruptionResumePending { recoveryWindow.postpone(until: now + 1) }
    }

    func displayConfigurationChanged() {
        synchronizeDisplayPowerAvailability()
        synchronizeAvailability()
        guard pendingDisplayInterruption == nil else { return }
        if running, let target = mapper.activeDisplayTarget {
            let currentDisplays = DisplayDiscovery.scan()
            let matching = currentDisplays.filter { $0.persistentUUID == target.persistentUUID }
            if matching.count == 1, let current = matching.first, current.canMap,
               current.matchesConfiguration(of: target) {
                displays = currentDisplays
                selectedDisplay = current.id
                return
            }
            guard releaseMapping() else {
                rememberStoppedState()
                return
            }
            handleMappingFailure(.deviceChanged(.displayValidation), previousDisplay: target)
            return
        }
        if !interruptions.isEmpty || interruptionResumePending || canRetryTargetChange {
            if running {
                resumePending = savedMapping?.resumeMapping == true
                interruptionResumePending = resumePending
                recoveryWindow.deadline = settlingContext?.deadline
                if !releaseMapping() {
                    rememberStoppedState()
                    return
                }
            }
            // Wait for one quiet second without extending the ten-second deadline.
            recoveryWindow.postpone(until: self.uptime() + 1)
            refresh(attemptResume: false)
        } else {
            stopForEnvironmentChange()
            refresh()
        }
    }

    func selectDevice(_ key: String) {
        guard key != selectedDevice else { return }
        selectedDevice = key
        selectionChanged()
    }

    func selectDisplay(_ id: UInt32) {
        guard id != selectedDisplay else { return }
        selectedDisplay = id
        selectionChanged()
    }

    func confirmTarget(_ confirmed: Bool) {
        confirmation.confirm(confirmed)
        if !confirmed { rememberStoppedState() }
    }

    private func selectionChanged() {
        restoreSavedSelection = false
        confirmation.invalidate()
        rememberStoppedState()
    }

    private func matches(_ device: TouchDevice, saved: SavedMapping) -> Bool {
        device.canMap && device.vendor == saved.vendor && device.product == saved.product
            && device.locationID == saved.locationID
    }

    private func rememberStoppedState() {
        cancelPendingResume()
        MappingPreferences.setResumeMapping(false)
        savedMapping = MappingPreferences.load()
    }

    private var canRetryTargetChange: Bool {
        guard !terminating, !modeRestorePending, let settlingContext,
              savedMapping?.resumeMapping == true else { return false }
        return !interruptions.isEmpty
            || settlingContext.deadline.map { self.uptime() < $0 } == true
    }

    private func handleMappingFailure(_ error: ProofError, previousDisplay: DisplayTarget? = nil) {
        if case .deviceChanged = error, canRetryTargetChange, let settlingContext {
            savedMapping = settlingContext.savedMapping
            resumePending = true
            interruptionResumePending = true
            recoveryWindow.deadline = settlingContext.deadline
            recoveryWindow.postpone(until: self.uptime() + 1)
            confirmation.invalidate()
            messageState = interruptions.isEmpty ? .mappingResuming : .mappingSuspended
            return
        }
        if case .deviceChanged(.displayValidation) = error, !terminating, !modeRestorePending,
           let previousDisplay, let savedMapping, savedMapping.resumeMapping,
           previousDisplay.persistentUUID == savedMapping.displayUUID {
            pendingDisplayInterruption = PendingDisplayInterruption(savedMapping: savedMapping,
                                                                    display: previousDisplay, error: error,
                                                                    expiresAt: self.uptime() + 2)
            resumePending = true
            interruptionResumePending = true
            recoveryWindow.deadline = nil
            messageState = .checkingInterruption
            synchronizeDisplayPowerAvailability()
            synchronizeAvailability()
            return
        }
        rememberStoppedState()
        confirmation.invalidate()
        recordFailure(.failure(error))
    }

    private func expirePendingDisplayInterruption() {
        guard let pendingDisplayInterruption,
              self.uptime() >= pendingDisplayInterruption.expiresAt else { return }
        rememberStoppedState()
        confirmation.invalidate()
        recordFailure(.interruptionUnconfirmed(pendingDisplayInterruption.error))
    }

    private func recordFailure(_ failure: ProofMessage) {
        lastFailureState = failure
        // Readiness is live; a past failure must not masquerade as its current blocker.
        messageState = .none
    }

    private func cancelPendingResume(clearSettling: Bool = true) {
        resumePending = false
        interruptionResumePending = false
        recoveryWindow.reset()
        if clearSettling {
            settlingContext = nil
            pendingDisplayInterruption = nil
        }
    }

    @discardableResult
    func stop() -> Bool {
        rememberStoppedState()
        return releaseMapping()
    }

    @discardableResult
    func stopForEnvironmentChange() -> Bool {
        // An independent display change still needs manual confirmation.
        let stopped = stop()
        if stopped { messageState = .environmentStopped }
        return stopped
    }

    @discardableResult
    func stopForTermination() -> Bool {
        // Cleanup must not turn a running session into a saved user pause.
        if pendingDisplayInterruption != nil { rememberStoppedState() }
        terminating = true
        cancelPendingResume()
        // An inactive predecessor record owns no input in this process.
        if startupRecoveryBlocked && !mapper.running && !mapper.modeRestorePending { return true }
        let stopped = releaseMapping()
        if !stopped && !mapper.modeRestorePending { return true }
        if !stopped { terminating = false }
        return stopped
    }

    @discardableResult
    func retryRestore() -> Bool {
        // Retrying failed quit cleanup is not an explicit request to pause.
        let restored = releaseMapping()
        if restored { refresh(attemptResume: false) }
        return restored
    }

    private func releaseMapping() -> Bool {
        if let error = mapper.stop() {
            if !mapper.modeRestorePending { startupRecoveryError = error }
            confirmation.invalidate()
            recordFailure(.failure(error))
            return false
        }
        startupRecoveryError = nil
        messageState = .mappingStopped
        return true
    }

    func openPermission(_ input: Bool) {
        let pane = input ? "Privacy_ListenEvent" : "Privacy_Accessibility"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct ProofSettingsView: View {
    @ObservedObject var model: ProofModel
    @ObservedObject private var language = LanguagePreferences.shared
    @StateObject private var login = LoginLaunchModel()
    var showTest: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Touch Me").font(.title)
                    Spacer()
                    Picker(Texts.get("언어", "Language"), selection: $language.selected) {
                        ForEach(AppLanguage.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu).controlSize(.small).fixedSize()
                }
                Text(Texts.get("터치 설정", "Touch settings")).font(.headline)
                Text(Texts.get("한 손가락 탭은 손을 뗄 때 클릭합니다. 손가락을 움직여 드래그하거나, 드래그 전에 두 손가락을 대고 클릭 없이 스크롤하세요. 동작을 바꾸려면 손가락을 모두 뗀 뒤 다시 시작하세요.",
                               "A one-finger tap clicks when you lift it. Move one finger to drag, or place two fingers before dragging to scroll without clicking. Lift all fingers before switching gestures."))
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                GroupBox(Texts.get("1. 권한 확인", "1. Permissions")) {
                    VStack(alignment: .leading, spacing: 10) {
                        permissionRow(Texts.get("입력 모니터링", "Input Monitoring"), granted: model.permissions.inputMonitoring, input: true)
                        permissionRow(Texts.get("손쉬운 사용", "Accessibility"), granted: model.permissions.accessibility, input: false)
                        Text(Texts.get("이 앱을 두 항목에 추가하고 허용한 뒤 돌아오세요. 적용되지 않으면 앱을 종료하고 다시 여세요.",
                                       "Add this app to both lists and allow it. If the status does not update, quit and reopen the app."))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
                GroupBox(Texts.get("2. 장치와 화면", "2. Device and display")) {
                    VStack(alignment: .leading, spacing: 10) {
                        if model.devices.isEmpty {
                            if !model.permissions.inputMonitoring {
                                Text(Texts.get("먼저 입력 모니터링을 허용한 뒤 다시 조회하세요. 현재 앱에서 장치를 확인하지 못했습니다.",
                                               "Allow Input Monitoring first, then refresh. No device is currently visible to this app."))
                            } else {
                                Text(Texts.get("USB 터치 장치를 확인하지 못했습니다. P16KT 연결·케이블을 확인하고 다시 조회하세요.",
                                               "No USB touch candidate was returned. Check the P16KT connection and cable, then refresh."))
                            }
                        } else {
                            Picker(Texts.get("터치 장치", "Touch device"), selection: Binding(get: { model.selectedDevice }, set: model.selectDevice)) {
                                ForEach(model.devices, id: \.key) { device in Text(deviceName(device)).tag(device.key) }
                            }
                            if model.devices.count > 1 {
                                Text(Texts.get("이 시험에서는 터치 패널 한 대만 연결해주세요.", "Connect only one touch panel for this proof."))
                            } else if model.devices.first?.canMap != true {
                                Text(Texts.get("장치 구분 또는 absolute X/Y·접촉 요소를 확인하지 못해 시작을 차단했습니다.",
                                               "Start is blocked: physical grouping or absolute contact elements could not be verified."))
                            }
                        }
                        Picker(Texts.get("대상 화면", "Target display"), selection: Binding(get: { model.selectedDisplay }, set: model.selectDisplay)) {
                            Text(Texts.get("화면 선택", "Select a display")).tag(UInt32(0))
                            ForEach(model.displays, id: \.id) { display in Text(displayName(display)).tag(display.id) }
                        }
                        Text(Texts.get("회전·미러링하지 않은 P16KT 화면을 선택하세요. 시작 전 시험 창을 열어 선택한 화면을 확인하세요.",
                                       "Select the unrotated, unmirrored P16KT display. Open the test window to confirm the target before starting."))
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button(Texts.get("다시 조회", "Refresh")) { model.refresh() }
                            Button(Texts.get("선택 화면에서 시험 창 열기", "Open test on selected display"), action: showTest)
                                .disabled(model.displays.first(where: { $0.id == model.selectedDisplay })?.canMap != true)
                        }
                        Toggle(Texts.get("시험 창이 P16KT에 표시되는 것을 확인했습니다", "I confirmed the test window is on the P16KT"), isOn: Binding(get: { model.targetConfirmed }, set: model.confirmTarget))
                        Text(Texts.get("현재 준비 상태", "Current readiness")).font(.caption).bold()
                        Text(model.readiness.text)
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                    }.padding(8).disabled(model.running || model.modeRestorePending)
                }
                GroupBox(Texts.get("3. 로그인 시작", "3. Launch at login")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(Texts.get("로그인 시 Touch Me 열기", "Open Touch Me at login"),
                               isOn: Binding(get: { login.enabled }, set: login.setEnabled))
                            .disabled(!login.installed && !login.enabled)
                        Text(Texts.get("기본값은 꺼짐입니다. 앱이 열리면 마지막 매핑 상태를 복원합니다.",
                                       "Off by default. When the app opens, it restores the last mapping state."))
                            .font(.caption).foregroundStyle(.secondary)
                        if !login.installed {
                            Text(Texts.get("Applications에 설치한 뒤 설정할 수 있습니다.",
                                           "Available after installing in Applications."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if login.requiresApproval {
                            Text(Texts.get("macOS의 로그인 항목 승인이 필요합니다.",
                                           "Approval is required in macOS Login Items."))
                            Button(Texts.get("로그인 항목 설정 열기", "Open Login Items settings")) { login.openSettings() }
                        }
                        if !login.message.isEmpty { Text(login.message).font(.callout) }
                    }.padding(8)
                }
                HStack {
                    Button(Texts.get("매핑 시작", "Start mapping")) { model.start() }.disabled(!model.canStart)
                    Button((model.modeRestorePending || model.startupRecoveryBlocked) && !model.running ? Texts.get("복구 재시도", "Retry restore") : Texts.get("중지", "Stop")) {
                        if (model.modeRestorePending || model.startupRecoveryBlocked) && !model.running { model.retryRestore() } else { model.stop() }
                    }
                        .disabled(!model.running && !model.modeRestorePending && !model.startupRecoveryBlocked && !model.resumePending).keyboardShortcut(".", modifiers: .command)
                    Text(model.running ? Texts.get("실행 중", "Running") : model.resumePending ? Texts.get("재개 대기", "Waiting to resume") : Texts.get("중지됨", "Stopped"))
                    Spacer()
                }
                Text(Texts.get("수신 값: \(model.values) · 게시한 누름: \(model.clicks)", "Received values: \(model.values) · Posted downs: \(model.clicks)"))
                    .font(.system(.caption, design: .monospaced))
                Text(Texts.get("관찰한 최대 접촉: \(model.maximumContacts) · 스크롤 이벤트: \(model.scrolls)",
                               "Maximum contacts observed: \(model.maximumContacts) · Scroll events: \(model.scrolls)"))
                    .font(.system(.caption, design: .monospaced))
                if !model.message.isEmpty { Text(model.message).font(.callout).fixedSize(horizontal: false, vertical: true) }
                if !model.lastFailureMessage.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Texts.get("마지막 오류 기록", "Last failure (history)")).font(.caption).bold()
                        Text(model.lastFailureMessage).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }.foregroundStyle(.secondary)
                }
                Text(Texts.get("실행 중 종료하면 다음 실행에서 재개하고, 중지하면 그 상태를 유지합니다. 처음 시작할 때 손을 뗀 뒤 탭하세요.",
                               "Quitting while running resumes on next launch; Stop stays stopped. Lift your finger before the first tap."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("\(AppVersion.release) · io.github.soom-kang.touchme").font(.caption2).foregroundStyle(.secondary)
            }.padding(24).frame(width: 590)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
    }

    private func permissionRow(_ name: String, granted: Bool, input: Bool) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(granted ? Texts.get("허용됨", "Allowed") : Texts.get("허용 필요", "Required"))
            Button(Texts.get("설정 열기", "Open settings")) { model.openPermission(input) }
        }
    }

    private func deviceName(_ device: TouchDevice) -> String {
        "\(Texts.get("USB 터치", "USB touch")) · \(String(format: "VID %04X / PID %04X", device.vendor, device.product))"
    }

    private func displayName(_ display: DisplayTarget) -> String {
        let name = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.id
        })?.localizedName ?? Texts.get("화면", "Display")
        let kind = Texts.get("화면", "Display")
        let reason = MappingReadiness.displayBlocker(display).map { " · " + $0.displayAnnotation } ?? ""
        return "\(name) · \(kind) \(display.id) · \(Int(display.bounds.width)) × \(Int(display.bounds.height))\(reason)"
    }
}

final class TouchTestView: NSView {
    private var points: [CGPoint] = []
    private var downCount = 0
    private var lastClickCount = 0
    private var languageChanges: AnyCancellable?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        observeLanguage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeLanguage()
    }

    private func observeLanguage() {
        languageChanges = LanguagePreferences.shared.$selected.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
    }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        points.append(convert(event.locationInWindow, from: nil))
        if points.count > 20 { points.removeFirst() }
        downCount += 1
        lastClickCount = event.clickCount
        needsDisplay = true
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { window?.close() } else { super.keyDown(with: event) }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        let style: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor.labelColor]
        (Texts.get("Touch Me · 두 손가락 스크롤 · 누름 \(downCount)", "Touch Me · Two-finger scrolling · Downs \(downCount)") as NSString)
            .draw(at: CGPoint(x: 24, y: 24), withAttributes: style)
        (Texts.get("두 손가락을 함께 위아래·좌우로 움직여보세요. 한 손가락은 탭·드래그입니다. Esc로 닫습니다.",
                   "Move two fingers together vertically or horizontally. One finger taps or drags. Press Esc to close.") as NSString)
            .draw(at: CGPoint(x: 24, y: 60), withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.secondaryLabelColor])
        (Texts.get("더블 클릭: \(lastClickCount >= 2 ? "감지됨" : "빠르게 두 번 탭하세요")",
                   "Double-click: \(lastClickCount >= 2 ? "detected" : "tap twice quickly")") as NSString)
            .draw(at: CGPoint(x: 24, y: 84), withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.secondaryLabelColor])
        for row in 0..<12 {
            for column in 0..<6 {
                let rect = NSRect(x: 24 + CGFloat(column) * 400, y: 108 + CGFloat(row) * 180, width: 380, height: 160)
                guard rect.intersects(dirtyRect) else { continue }
                NSColor.separatorColor.setStroke()
                NSBezierPath(rect: rect).stroke()
                ("\(row + 1) · \(column + 1)" as NSString).draw(at: CGPoint(x: rect.minX + 20, y: rect.minY + 20), withAttributes: style)
            }
        }
        for point in points {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)).fill()
        }
    }
}
