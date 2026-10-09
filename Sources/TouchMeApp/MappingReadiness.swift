import TouchMePlatform

/// The same typed result controls Start and explains its first blocking condition.
enum MappingReadiness: Equatable {
    case ready, terminating, running, restoreRequired, checkingInterruption
    case protectedDataUnavailable, sessionUnavailable, inactiveSession, sleeping, displaysSleeping
    case permissionsRequired, inputMonitoringRequired, accessibilityRequired
    case deviceQueryFailed, noDevice, multipleDevices, selectDevice, unsupportedModel
    case unverifiedDescriptor, missingLocation, selectDisplay, builtInDisplay, mirroredDisplay
    case rotatedDisplay, invalidDisplayBounds, missingDisplayUUID, targetConfirmationRequired

    var canStart: Bool { self == .ready }

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
            return Texts.get("원래 장치 모드 복구가 필요합니다. P16KT를 같은 USB 포트에 연결한 뒤 ‘복구 재시도’를 누르세요.",
                             "The original device mode still needs restoring. Connect the P16KT to the same USB port and choose Retry restore.")
        case .checkingInterruption:
            return Texts.get("화면 변경 후 잠금·절전 여부를 확인하고 있습니다. 잠시 기다리세요.",
                             "Checking for a lock or sleep interruption after a display change. Please wait.")
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
