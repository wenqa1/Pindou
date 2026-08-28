import XCTest
@testable import BeanWarehouseApp

final class BeanWarehouseAppTests: XCTestCase {
    func testInventorySKUIdentityKeepsBrandAndSeries() {
        let first = BeadSKU(brandID: "Perler", seriesID: "Standard", colorCode: "F22")
        let second = BeadSKU(brandID: "Mard", seriesID: "Standard", colorCode: "F22")

        XCTAssertNotEqual(first, second)
    }
}
