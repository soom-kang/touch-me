import Foundation

/// Owns only changes made by this process. The I/O closures never authorize a
/// replacement device; P16KTDeviceMode must validate its native handles first.
final class DeviceModeTransaction {
    typealias Pair = (mode: Int, identifier: Int)
    let original: Pair
    private(set) var needsRestore = false
    var read: () throws -> Pair
    var write: (Pair) throws -> Void

    init(read: @escaping () throws -> Pair, write: @escaping (Pair) throws -> Void) throws {
        let original = try read()
        guard (original.mode == 0 || original.mode == 2), original.identifier == 0 else {
            throw ProofError.modeStateUnexpected
        }
        self.original = original
        self.read = read
        self.write = write
    }

    func enable() throws {
        guard original.mode == 0 else { return }
        // Even a failing write may have partially changed the panel.
        needsRestore = true
        try write((2, original.identifier))
        guard try matches((2, original.identifier)) else { throw ProofError.modeReadbackMismatch }
    }

    func restore() throws {
        guard needsRestore else { return }
        if (try? matches(original)) != true {
            try write(original)
            guard try matches(original) else { throw ProofError.modeReadbackMismatch }
        }
        // Only verified readback releases the recovery responsibility.
        needsRestore = false
    }

    private func matches(_ expected: Pair) throws -> Bool {
        let actual = try read()
        return actual.mode == expected.mode && actual.identifier == expected.identifier
    }
}
