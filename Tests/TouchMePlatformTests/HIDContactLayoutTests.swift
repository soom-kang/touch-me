import Testing
import TouchMappingCore
@testable import TouchMePlatform

struct HIDContactLayoutTests {
    private let axis = HIDContactLayout.Axis(range: AxisRange(minimum: 0, maximum: 1000))

    private func finger(_ cookie: UInt32) -> HIDContactLayout.Group {
        HIDContactLayout.Group(cookie: cookie, isFinger: true, x: [axis], y: [axis],
                               tipCount: 1, hasDigitizerTip: true)
    }

    private func collection(_ groups: [HIDContactLayout.Group], descriptorVerified: Bool = true) -> HIDMappingEligibility.Collection {
        let cookies = HIDContactLayout.validatedCookies(groups)
        return HIDMappingEligibility.Collection(descriptorVerified: descriptorVerified && cookies != nil,
            isPointer: true, contactCount: cookies?.count ?? 0, hasKeyboardElements: false)
    }

    @Test
    func incompleteSecondFingerRejectsWholeDescriptor() {
        var missingY = finger(2)
        missingY.y = []
        var duplicateX = finger(2)
        duplicateX.x.append(axis)
        var invalidRange = finger(2)
        invalidRange.y = [.init(range: AxisRange(minimum: 10, maximum: 10))]
        var relativeX = finger(2)
        relativeX.x = [.init(range: axis.range, isRelative: true)]
        let emptyFinger = HIDContactLayout.Group(cookie: 2, isFinger: true)
        let orphanTip = HIDContactLayout.Group(cookie: 0, tipCount: 1, hasDigitizerTip: true)
        for incomplete in [missingY, duplicateX, invalidRange, relativeX, emptyFinger, orphanTip] {
            let groups = [finger(1), incomplete]
            #expect(HIDContactLayout.validatedCookies(groups) == nil)
            #expect(!HIDMappingEligibility.canMap(groupingVerified: true, collections: [collection(groups)]))
        }
    }

    @Test
    func validContactsIgnoreUnrelatedGroupsWithoutWeakeningDescriptorAndSiblingGuards() {
        let groups = [finger(1), finger(2), HIDContactLayout.Group(cookie: 3),
                      HIDContactLayout.Group(cookie: 4, x: [axis])]
        #expect(HIDContactLayout.validatedCookies(groups) == Set<UInt32>([1, 2]))
        let valid = collection(groups)
        #expect(HIDMappingEligibility.canMap(groupingVerified: true, collections: [valid]))
        #expect(!HIDMappingEligibility.canMap(groupingVerified: false, collections: [valid]))
        // Failed full-descriptor queries and contradictory usage metadata remain blocked.
        #expect(!HIDMappingEligibility.canMap(groupingVerified: true,
            collections: [collection(groups, descriptorVerified: false)]))
        #expect(!HIDMappingEligibility.canMap(groupingVerified: true, collections: [collection([])]))
        let keyboardSibling = HIDMappingEligibility.Collection(descriptorVerified: true,
            isPointer: false, contactCount: 0, hasKeyboardElements: true)
        #expect(!HIDMappingEligibility.canMap(groupingVerified: true, collections: [valid, keyboardSibling]))
        let unreadableSibling = HIDMappingEligibility.Collection(descriptorVerified: false,
            isPointer: false, contactCount: 0, hasKeyboardElements: false)
        #expect(!HIDMappingEligibility.canMap(groupingVerified: true, collections: [valid, unreadableSibling]))
    }
}
