import Foundation
import Testing

@Suite(.serialized)
struct MainViewStateTests {
    @Test
    func dataSaverPolicyDisablesHDPreferenceWhenEnabled() {
        #expect(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: true, preferHDImages: true) == false)
        #expect(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: true, preferHDImages: false) == false)
    }

    @Test
    func dataSaverPolicyPreservesHDPreferenceWhenDisabled() {
        #expect(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: false, preferHDImages: true) == true)
        #expect(DataSaverPreferencePolicy.resolvedPreferHDImages(dataSaverMode: false, preferHDImages: false) == false)
    }
}
