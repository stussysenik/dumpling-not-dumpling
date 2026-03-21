import XCTest
@testable import DumplingNotDumpling

/// Verifies that Carbon spacing tokens follow the 8px grid contract and meet
/// minimum WCAG 2.5.5 tap-target requirements.
final class DesignTokenTests: XCTestCase {

    // MARK: - Spacing Grid

    /// Anchors three representative values in the spacing scale to catch
    /// any accidental edits to the constants.
    func testSpacingGrid() {
        XCTAssertEqual(CarbonSpacing.spacing03, 8,  "spacing03 must be 8px (base unit)")
        XCTAssertEqual(CarbonSpacing.spacing05, 16, "spacing05 must be 16px (default padding)")
        XCTAssertEqual(CarbonSpacing.spacing07, 32, "spacing07 must be 32px (major gap)")
    }

    /// spacing09 (48px) is the minimum interactive element height specified by
    /// WCAG 2.5.5 (Target Size) and Carbon's own button sizing guide.
    func testMinTapTarget() {
        XCTAssertGreaterThanOrEqual(
            CarbonSpacing.spacing09, 48,
            "spacing09 must be ≥ 48px to meet WCAG 2.5.5 tap-target requirements"
        )
    }

    // MARK: - Spacing Scale Monotonicity

    /// Every step in the scale should be strictly larger than the previous one.
    func testSpacingScaleIsMonotonicallyIncreasing() {
        let scale: [CGFloat] = [
            CarbonSpacing.spacing02,
            CarbonSpacing.spacing03,
            CarbonSpacing.spacing04,
            CarbonSpacing.spacing05,
            CarbonSpacing.spacing06,
            CarbonSpacing.spacing07,
            CarbonSpacing.spacing08,
            CarbonSpacing.spacing09,
        ]
        for i in 1 ..< scale.count {
            XCTAssertGreaterThan(
                scale[i], scale[i - 1],
                "spacing scale must be strictly increasing at index \(i)"
            )
        }
    }
}
