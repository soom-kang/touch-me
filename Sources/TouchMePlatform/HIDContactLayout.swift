import TouchMappingCore

/// Descriptor-only evidence, shared by discovery and the fail-closed checks.
enum HIDContactLayout {
    struct Axis {
        let range: AxisRange
        var isRelative = false
    }

    struct Group {
        let cookie: UInt32
        var isFinger = false
        var x: [Axis] = []
        var y: [Axis] = []
        var tipCount = 0
        var hasDigitizerTip = false

        var isContactCandidate: Bool {
            isFinger || hasDigitizerTip || (tipCount > 0 && (!x.isEmpty || !y.isEmpty))
        }
    }

    /// nil rejects the entire descriptor, including otherwise valid contacts.
    static func validatedCookies(_ groups: [Group]) -> Set<UInt32>? {
        var cookies: Set<UInt32> = []
        for group in groups where group.isContactCandidate {
            guard group.cookie != 0, group.x.count == 1, group.y.count == 1, group.tipCount == 1,
                  let x = group.x.first, let y = group.y.first,
                  !x.isRelative, !y.isRelative, x.range.isValid, y.range.isValid,
                  cookies.insert(group.cookie).inserted else { return nil }
        }
        return cookies
    }
}

enum HIDMappingEligibility {
    struct Collection {
        let descriptorVerified: Bool
        let isPointer: Bool
        let contactCount: Int
        let hasKeyboardElements: Bool
    }

    static func canMap(groupingVerified: Bool, collections: [Collection]) -> Bool {
        let pointers = collections.filter(\.isPointer)
        return groupingVerified && !pointers.isEmpty
            && collections.allSatisfy(\.descriptorVerified)
            && pointers.allSatisfy { $0.contactCount > 0 }
            && !collections.contains { $0.hasKeyboardElements }
    }
}
