import XCTest
@testable import DumplingNotDumpling

#if canImport(UIKit)
import UIKit

final class ClassificationServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Render a solid-colour 224×224 image suitable for the stub model.
    private func makeTestImage(color: UIColor) -> CGImage? {
        let size = CGSize(width: 224, height: 224)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.cgImage
    }

    // MARK: - Tests

    /// Verify that `classify` returns a non-nil result with a valid label,
    /// a confidence in [0, 1], and at least one entry in `allResults`.
    @MainActor
    func testClassifyReturnsResult() async throws {
        let service = ClassificationService()

        guard let cgImage = makeTestImage(color: .brown) else {
            XCTFail("Failed to create test CGImage")
            return
        }

        let result = await service.classify(cgImage: cgImage, mode: .party)

        XCTAssertNotNil(result, "classify should return a result for a valid image")
        guard let result else { return }

        XCTAssertFalse(result.label.isEmpty, "label should not be empty")
        XCTAssertGreaterThanOrEqual(result.confidence, 0, "confidence must be ≥ 0")
        XCTAssertLessThanOrEqual(result.confidence, 1, "confidence must be ≤ 1")
        XCTAssertFalse(result.allResults.isEmpty, "allResults should contain at least one entry")
    }

    /// `partyConfidence` is defined as the sum of confidences for all labels
    /// that are NOT `not_dumpling`.  Verify that the value computed by the
    /// service matches a manual reduction over `allResults`.
    @MainActor
    func testPartyModeAggregation() async throws {
        let service = ClassificationService()

        guard let cgImage = makeTestImage(color: .orange) else { return }

        let result = await service.classify(cgImage: cgImage, mode: .party)
        guard let result else { return }

        let manualSum = result.allResults
            .filter { $0.label != "not_dumpling" }
            .reduce(Float(0)) { $0 + $1.confidence }

        XCTAssertEqual(
            result.partyConfidence,
            manualSum,
            accuracy: 0.001,
            "partyConfidence should equal the sum of non-not_dumpling confidences"
        )
    }

    /// Confirm that `isClassifying` is false after classification completes
    /// (the `defer` in `classify` must run correctly).
    @MainActor
    func testIsClassifyingResetAfterClassification() async throws {
        let service = ClassificationService()

        guard let cgImage = makeTestImage(color: .blue) else { return }

        // isClassifying starts false
        XCTAssertFalse(service.isClassifying)

        _ = await service.classify(cgImage: cgImage, mode: .full)

        // After the await, it must be false again
        XCTAssertFalse(service.isClassifying, "isClassifying should be false after classify returns")
    }

    /// `allResults` entries should sum to approximately 1.0 for a valid model.
    @MainActor
    func testAllResultsSumToOne() async throws {
        let service = ClassificationService()

        guard let cgImage = makeTestImage(color: .red) else { return }

        let result = await service.classify(cgImage: cgImage, mode: .full)
        guard let result else { return }

        let total = result.allResults.reduce(Float(0)) { $0 + $1.confidence }
        XCTAssertEqual(total, 1.0, accuracy: 0.01, "All result confidences should sum to ~1.0")
    }
}

#endif // canImport(UIKit)
