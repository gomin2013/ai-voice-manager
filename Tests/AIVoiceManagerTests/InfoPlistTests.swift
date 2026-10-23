import XCTest
@testable import AIVoiceManagerApp

final class InfoPlistTests: XCTestCase {
    private var plist: NSDictionary? {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/AIVoiceManagerApp/Info.plist")
        return NSDictionary(contentsOf: url)
    }

    /// build-app.sh copies Info.plist; an executable renamed in Package.swift but not here won't launch.
    func testInfoPlistNamesTheExecutable() throws {
        let plist = try XCTUnwrap(plist)
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "AIVoiceManager")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.aivoicemanager.app")
        XCTAssertEqual(plist["LSMinimumSystemVersion"] as? String, "14.0")
        // build-app.sh copies Packaging/Assets.car (macOS 26) + AppIcon.icns (14–15): both are found by this name
        XCTAssertEqual(plist["CFBundleIconName"] as? String, "AppIcon")
        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "AppIcon")
    }
}
