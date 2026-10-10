import Testing
@testable import TouchMePlatform

struct DeviceModeTransactionTests {
    private enum Failure: Error { case injected }

    @Test func automaticReconnectUsesOpenedBaselineWithoutWritingModeTwo() throws {
        for initial in [0, 2] {
            var pair: DeviceModeTransaction.Pair = (initial, 0)
            var writes = 0
            let transaction = try DeviceModeTransaction(read: { pair }, write: { pair = $0; writes += 1 })
            if initial == 0 {
                try transaction.requireDefaultModeForAutomaticReconnect()
            } else {
                #expect(throws: ProofError.self) { try transaction.requireDefaultModeForAutomaticReconnect() }
                try transaction.enable()
                try transaction.restore()
            }
            #expect(writes == 0)
            #expect(pair.mode == initial)
        }
    }

    @Test func normalModesAndLostProcessState() throws {
        for initial in [0, 2] {
            var pair: DeviceModeTransaction.Pair = (initial, 0)
            var writes: [Int] = []
            let owner = try DeviceModeTransaction(read: { pair }, write: { pair = $0; writes.append($0.mode) })
            try owner.enable()
            // A new process cannot infer the previous owner's original value.
            let restarted = try DeviceModeTransaction(read: { pair }, write: { pair = $0 })
            #expect(!restarted.needsRestore)
            try restarted.restore()
            #expect(pair.mode == 2)
            try owner.restore()
            #expect(pair.mode == initial)
            #expect(writes == (initial == 0 ? [2, 0] : []))
        }
    }

    @Test func partialWriteAndFailedRestorationKeepResponsibility() throws {
        var pair: DeviceModeTransaction.Pair = (0, 0)
        var failWrite = true
        let owner = try DeviceModeTransaction(read: { pair }, write: {
            pair = $0
            if failWrite { throw Failure.injected }
        })
        #expect(throws: Failure.self) { try owner.enable() }
        #expect(owner.needsRestore)
        #expect(throws: Failure.self) { try owner.restore() }
        #expect(owner.needsRestore)
        failWrite = false
        try owner.restore()
        #expect(!owner.needsRestore)
        #expect(pair.mode == 0)
    }

    @Test func readbackFailuresAndReboundIOPreserveOriginal() throws {
        var pair: DeviceModeTransaction.Pair = (0, 0)
        let owner = try DeviceModeTransaction(read: { pair }, write: { _ in })
        #expect(throws: ProofError.self) { try owner.enable() }
        #expect(owner.needsRestore)
        owner.read = { throw Failure.injected }
        #expect(throws: Failure.self) { try owner.restore() }
        #expect(owner.needsRestore)
        // Native descriptor/location validation precedes replacing these closures.
        pair = (2, 0)
        owner.read = { pair }
        owner.write = { pair = $0 }
        try owner.restore()
        #expect(pair.mode == 0)
        #expect(!owner.needsRestore)
    }
}
