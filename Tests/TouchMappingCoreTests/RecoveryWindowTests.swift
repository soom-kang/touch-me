import Testing
import TouchMappingCore

struct RecoveryWindowTests {
    @Test func settlingDoesNotExtendTheDeadline() {
        var window = RecoveryWindow()
        window.begin(at: 100)
        window.postpone(until: 109.5)
        window.postpone(until: 111)
        #expect(window.deadline == 110)
        #expect(window.nextAttempt == 111)
        #expect(!window.hasExpired(at: 109.99))
        #expect(window.hasExpired(at: 110))
        window.reset()
        #expect(window.deadline == nil)
        #expect(window.nextAttempt == 0)
    }
}
