import XCTest
@testable import PindouApp

final class AppSectionTests: XCTestCase {
    func testSectionIdentifiersAreUnique() {
        let identifiers = AppSection.allCases.map(\.id)

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }

    func testFirstReleaseContainsCoreWorkflowSections() {
        let sections = Set(AppSection.allCases)

        XCTAssertTrue(sections.isSuperset(of: [.library, .inventory, .importPattern, .build]))
    }
}

