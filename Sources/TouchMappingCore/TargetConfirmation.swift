/// Restoring a saved identity must not override a user's request to reconfirm it.
public struct TargetConfirmation {
    public private(set) var isConfirmed = false
    private var allowsSavedConfirmation = true

    public init() {}

    public mutating func confirm(_ confirmed: Bool) {
        isConfirmed = confirmed
        allowsSavedConfirmation = confirmed
    }

    public mutating func invalidate() { isConfirmed = false }

    public mutating func restore(savedTargetMatches: Bool) {
        isConfirmed = allowsSavedConfirmation && savedTargetMatches
    }
}
