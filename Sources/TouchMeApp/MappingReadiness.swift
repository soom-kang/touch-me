import TouchMePlatform

/// The same typed result controls Start and explains its first blocking condition.
enum MappingReadiness: Equatable {
    case ready, terminating, running, restoreRequired, recordedRestoreRequired, checkingInterruption
    case protectedDataUnavailable, sessionUnavailable, inactiveSession, sleeping, displaysSleeping
    case permissionsRequired, inputMonitoringRequired, accessibilityRequired
    case deviceQueryFailed, noDevice, multipleDevices, selectDevice, unsupportedModel
    case unverifiedDescriptor, missingLocation, selectDisplay, builtInDisplay, mirroredDisplay
    case rotatedDisplay, invalidDisplayBounds, missingDisplayUUID, targetConfirmationRequired
    case waitingReconnect, reconnectManualStartRequired

    var canStart: Bool { self == .ready || self == .reconnectManualStartRequired }

    static func displayBlocker(_ display: DisplayTarget) -> Self? {
        if display.builtIn { return .builtInDisplay }
        if display.mirrored { return .mirroredDisplay }
        if display.rotated { return .rotatedDisplay }
        if !display.canMap { return .invalidDisplayBounds }
        if display.persistentUUID == nil { return .missingDisplayUUID }
        return nil
    }

    var text: String {
        switch self {
        case .ready:
            return Texts.get("매핑을 시작할 준비가 되었습니다.", "Ready to start mapping.")
        case .terminating:
            return Texts.get("종료를 위해 매핑을 정리하고 있습니다.", "Finishing mapping cleanup before quitting.")
        case .running:
            return Texts.get("매핑이 실행 중입니다. 대상을 바꾸려면 먼저 중지하세요.",
                             "Mapping is running. Stop before changing the target.")
        case .restoreRequired:
            return Texts.get("장치 모드 복구 또는 연결 종료 기록 처리가 남아 있습니다. 아래 오류를 확인하고 ‘복구 재시도’를 누르세요.",
                             "Device-mode restoration or ended-attachment record processing is still pending. Check the error below and choose Retry restore.")
        case .recordedRestoreRequired:
            return Texts.get("이전 실행의 복구 기록을 확인하지 못해 매핑을 차단했습니다. 아래 오류를 확인하고 ‘복구 재시도’를 누르세요. 기록을 보존한 채 정상 종료할 수 있습니다.",
                             "Mapping is blocked by the previous session's recovery record. Check the error below and choose Retry restore. Normal Quit preserves the record.")
        case .checkingInterruption:
            return Texts.get("화면 변경 후 USB 연결과 잠금·절전 여부를 확인하고 있습니다. 잠시 기다리세요.",
                             "Checking the USB attachment and lock or sleep state after a display change. Please wait.")
        case .waitingReconnect:
            return Texts.get("USB 연결이 끊겼습니다. 같은 포트에 P16KT를 다시 연결하세요. 다시 조회할 수 있으며 ‘중지’를 누르면 대기를 취소합니다.",
                             "USB disconnected. Reconnect the P16KT to the same port. Refresh is available; Stop cancels the wait.")
        case .reconnectManualStartRequired:
            return Texts.get("재연결한 장치가 모드 2를 유지하고 있습니다. 자동 재개를 멈췄습니다. ‘매핑 시작’을 누르면 현재 모드를 그대로 사용합니다.",
                             "The reconnected device retained mode 2, so automatic resume stopped. Start mapping uses its current mode without resetting it.")
        case .protectedDataUnavailable:
            return Texts.get("Mac 잠금을 해제한 뒤 시작할 수 있습니다.", "Unlock the Mac before starting mapping.")
        case .sessionUnavailable:
            return Texts.get("현재 로그인 세션을 조회하지 못했습니다. 잠시 후 다시 조회하세요.",
                             "The current login session could not be read. Wait briefly, then refresh.")
        case .inactiveSession:
            return Texts.get("이 사용자의 로그인이 완료되고 세션이 활성화되어야 합니다.",
                             "Wait for this user's login to finish and return to their active session.")
        case .sleeping:
            return Texts.get("Mac이 절전 상태에서 돌아오기를 기다리고 있습니다.", "Waiting for the Mac to wake from sleep.")
        case .displaysSleeping:
            return Texts.get("화면이 켜지기를 기다리고 있습니다. 화면을 깨운 뒤 다시 시도하세요.",
                             "Waiting for the display to wake. Wake the display, then try again.")
        case .permissionsRequired:
            return Texts.get("입력 모니터링과 손쉬운 사용 권한을 모두 허용해주세요.",
                             "Allow both Input Monitoring and Accessibility permissions.")
        case .inputMonitoringRequired:
            return Texts.get("입력 모니터링 권한을 허용한 뒤 다시 조회하세요.",
                             "Allow Input Monitoring, then refresh.")
        case .accessibilityRequired:
            return Texts.get("손쉬운 사용 권한을 허용해주세요.", "Allow Accessibility permission.")
        case .deviceQueryFailed:
            return Texts.get("USB 터치 장치 조회 결과를 받지 못했습니다. 연결과 권한을 확인한 뒤 다시 조회하세요.",
                             "The USB touch query returned no device set. Check the connection and permissions, then refresh.")
        case .noDevice:
            return Texts.get("USB 터치 장치가 없습니다. P16KT 연결과 케이블을 확인한 뒤 다시 조회하세요.",
                             "No USB touch device was found. Check the P16KT connection and cable, then refresh.")
        case .multipleDevices:
            return Texts.get("터치 패널 한 대만 연결한 뒤 다시 조회하세요.", "Connect only one touch panel, then refresh.")
        case .selectDevice:
            return Texts.get("연결된 터치 장치를 선택해주세요.", "Select the connected touch device.")
        case .unsupportedModel:
            return Texts.get("현재 지원하는 모델은 확인된 P16KT(VID 0457 / PID 0819)입니다. 다른 패널은 시작할 수 없습니다.",
                             "Only the verified P16KT (VID 0457 / PID 0819) is supported. Other panels cannot start mapping.")
        case .unverifiedDescriptor:
            return Texts.get("장치 구분 또는 absolute X/Y·접촉 요소를 확인하지 못했습니다. 연결을 확인한 뒤 다시 조회하세요.",
                             "Physical grouping or absolute X/Y and contact elements could not be verified. Check the connection, then refresh.")
        case .missingLocation:
            return Texts.get("USB 위치 ID를 확인하지 못했습니다. P16KT를 다시 연결한 뒤 다시 조회하세요.",
                             "The USB location ID could not be verified. Reconnect the P16KT, then refresh.")
        case .selectDisplay:
            return Texts.get("대상 외부 화면을 선택해주세요. 목록에 없다면 연결 후 다시 조회하세요.",
                             "Select the target external display. If it is missing, connect it and refresh.")
        case .builtInDisplay:
            return Texts.get("내장 화면은 지원하지 않습니다. P16KT 외부 화면을 선택하세요.",
                             "Built-in displays are not supported. Select the external P16KT display.")
        case .mirroredDisplay:
            return Texts.get("미러링된 화면은 지원하지 않습니다. 미러링을 끈 뒤 다시 조회하세요.",
                             "Mirrored displays are not supported. Turn off mirroring, then refresh.")
        case .rotatedDisplay:
            return Texts.get("회전된 화면은 지원하지 않습니다. 화면 회전을 해제한 뒤 다시 조회하세요.",
                             "Rotated displays are not supported. Turn off display rotation, then refresh.")
        case .invalidDisplayBounds:
            return Texts.get("화면 영역을 확인하지 못했습니다. 화면 연결을 확인한 뒤 다시 조회하세요.",
                             "The display bounds could not be verified. Check the display connection, then refresh.")
        case .missingDisplayUUID:
            return Texts.get("화면의 고유 UUID를 확인하지 못했습니다. 화면을 다시 연결한 뒤 다시 조회하세요.",
                             "The persistent display UUID could not be verified. Reconnect the display, then refresh.")
        case .targetConfirmationRequired:
            return Texts.get("시험 창을 열고 P16KT에 표시되는지 확인한 뒤 확인란을 선택하세요.",
                             "Open the test window, verify it is on the P16KT, then select the confirmation checkbox.")
        }
    }

    var displayAnnotation: String {
        switch self {
        case .builtInDisplay: return Texts.get("내장 · 지원 안 함", "built-in · unsupported")
        case .mirroredDisplay: return Texts.get("미러링 · 지원 안 함", "mirrored · unsupported")
        case .rotatedDisplay: return Texts.get("회전 · 지원 안 함", "rotated · unsupported")
        case .invalidDisplayBounds: return Texts.get("화면 영역 미확인", "bounds unverified")
        case .missingDisplayUUID: return Texts.get("UUID 미확인", "UUID unverified")
        default: return ""
        }
    }
}
