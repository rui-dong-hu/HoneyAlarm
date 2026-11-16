import XCTest
@testable import HoneyAlarm

final class HoneyAlarmTests: XCTestCase {

    func testTimeComponentsNormalization() throws {
        // 用午夜 00:00
        let cal = Calendar.current
        let midnight = cal.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        let c1 = alarmTimeComponents(midnight)
        XCTAssertEqual(c1.hour, 0)
        XCTAssertEqual(c1.minute, 0)

        // 用 23:59
        let late = cal.date(bySettingHour: 23, minute: 59, second: 0, of: Date())!
        let c2 = alarmTimeComponents(late)
        XCTAssertEqual(c2.hour, 23)
        XCTAssertEqual(c2.minute, 59)

        // 秒数应被清零
        let withSecs = cal.date(bySettingHour: 10, minute: 20, second: 45, of: Date())!
        let c3 = alarmTimeComponents(withSecs)
        XCTAssertEqual(c3.second, 0)

        // 随机时间：hour/min 落在合法区间
        for hour in 0...23 {
            for minute in stride(from: 0, to: 60, by: 7) {
                let d = cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
                let c = alarmTimeComponents(d)
                XCTAssertTrue((c.hour ?? -1) >= 0 && (c.hour ?? 24) <= 23)
                XCTAssertTrue((c.minute ?? -1) >= 0 && (c.minute ?? 60) <= 59)
            }
        }
    }
}