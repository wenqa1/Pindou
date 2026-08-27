import Foundation
import XCTest
@testable import PindouApp

final class PatternMatrixTests: XCTestCase {
    func testUsageCountsOnlyNonEmptyCellsByPaletteSKU() throws {
        let matrix = try PatternMatrix(
            rows: 2,
            columns: 3,
            palette: [
                PatternPaletteEntry(skuID: "F22"),
                PatternPaletteEntry(skuID: "C15")
            ],
            cells: [
                .color(paletteIndex: 0, confidence: .userConfirmed),
                .empty,
                .color(paletteIndex: 1, confidence: .legendVerified),
                .color(paletteIndex: 0, confidence: .paletteInferred),
                .empty,
                .empty
            ]
        )

        XCTAssertEqual(matrix.usage, ["C15": 1, "F22": 2])
        XCTAssertEqual(matrix.nonEmptyCellCount, 3)
    }

    func testBinaryCodecRoundTripsPaletteCellsAndConfidence() throws {
        let original = try PatternMatrix(
            rows: 1,
            columns: 3,
            palette: [
                PatternPaletteEntry(skuID: "F22"),
                PatternPaletteEntry(skuID: "15")
            ],
            cells: [
                .color(paletteIndex: 1, confidence: .legendVerified),
                .empty,
                .color(paletteIndex: 0, confidence: .paletteInferred)
            ]
        )

        let encoded = try PatternMatrixCodec().encode(original)
        let decoded = try PatternMatrixCodec().decode(encoded)

        XCTAssertEqual(decoded, original)
    }

    func testHorizontalMirrorReversesEveryRowWithoutChangingUsage() throws {
        let matrix = try PatternMatrix(
            rows: 2,
            columns: 3,
            palette: [
                PatternPaletteEntry(skuID: "F22"),
                PatternPaletteEntry(skuID: "C15")
            ],
            cells: [
                .color(paletteIndex: 0, confidence: .userConfirmed),
                .empty,
                .color(paletteIndex: 1, confidence: .userConfirmed),
                .empty,
                .color(paletteIndex: 1, confidence: .userConfirmed),
                .color(paletteIndex: 0, confidence: .userConfirmed)
            ]
        )

        let mirrored = matrix.mirroredHorizontally()

        XCTAssertEqual(mirrored.cells, [
            .color(paletteIndex: 1, confidence: .userConfirmed),
            .empty,
            .color(paletteIndex: 0, confidence: .userConfirmed),
            .color(paletteIndex: 0, confidence: .userConfirmed),
            .color(paletteIndex: 1, confidence: .userConfirmed),
            .empty
        ])
        XCTAssertEqual(mirrored.usage, matrix.usage)
    }

    func testMatrixRejectsOutOfRangePaletteIndex() {
        XCTAssertThrowsError(
            try PatternMatrix(
                rows: 1,
                columns: 1,
                palette: [PatternPaletteEntry(skuID: "F22")],
                cells: [.color(paletteIndex: 1, confidence: .userConfirmed)]
            )
        ) { error in
            XCTAssertEqual(
                error as? PatternMatrixError,
                .paletteIndexOutOfBounds(index: 1, paletteCount: 1)
            )
        }
    }

    func testCodecRejectsTruncatedData() {
        XCTAssertThrowsError(try PatternMatrixCodec().decode(Data([0x50, 0x44]))) { error in
            XCTAssertEqual(error as? PatternMatrixCodecError, .truncatedData)
        }
    }
}
