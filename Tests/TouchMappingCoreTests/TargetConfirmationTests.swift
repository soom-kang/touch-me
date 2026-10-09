import Testing
@testable import TouchMappingCore

struct TargetConfirmationTests {
    @Test func cancellationSurvivesRepeatedSavedTargetRefresh() {
        var confirmation = TargetConfirmation()
        confirmation.restore(savedTargetMatches: true)
        #expect(confirmation.isConfirmed)

        // Unchecking the box and opening a fresh test window use this same operation.
        confirmation.confirm(false)
        for _ in 0..<2 {
            confirmation.invalidate()
            confirmation.restore(savedTargetMatches: true)
            #expect(!confirmation.isConfirmed)
        }
        confirmation.confirm(true)
        confirmation.restore(savedTargetMatches: true)
        #expect(confirmation.isConfirmed)
    }

    @Test func changedTargetRequiresConfirmation() {
        var confirmation = TargetConfirmation()
        confirmation.restore(savedTargetMatches: false)
        #expect(!confirmation.isConfirmed)
        confirmation.confirm(true)
        confirmation.invalidate()
        #expect(!confirmation.isConfirmed)
    }
}
