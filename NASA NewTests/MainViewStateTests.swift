import XCTest
@testable import NASA_New

final class MainViewStateTests: XCTestCase {
    func testDataSaverPolicyDisablesHDPreferenceWhenEnabled() {
        XCTAssertFalse(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: true, preferHDImages: true))
        XCTAssertFalse(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: true, preferHDImages: false))
    }

    func testDataSaverPolicyPreservesHDPreferenceWhenDisabled() {
        XCTAssertTrue(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: false, preferHDImages: true))
        XCTAssertFalse(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: false, preferHDImages: false))
    }
}
