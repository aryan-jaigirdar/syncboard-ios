import XCTest

/// Runs against a local paired server. It creates a fresh, disposable board.
@MainActor
final class OfflineJourneyTests: XCTestCase {
    func testOfflineCardSurvivesRelaunchAndReachesTheWebServer() async throws {
        let server = "http://127.0.0.1:3090"
        var request = URLRequest(url: URL(string: server + "/api/boards")!)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 201)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        let boardID = try XCTUnwrap(object["id"])
        let app = XCUIApplication()
        app.launchArguments = ["--server", server, "--board", boardID]
        app.launch()
        XCTAssertTrue(app.staticTexts["Live"].waitForExistence(timeout: 15))
        app.swipeUp()
        let offline = app.switches["offline-toggle"]
        XCTAssertTrue(offline.waitForExistence(timeout: 5))
        offline.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let enabled = NSPredicate(format: "value == %@", "1")
        let offlineEnabled = XCTNSPredicateExpectation(predicate: enabled, object: offline)
        XCTAssertEqual(XCTWaiter.wait(for: [offlineEnabled], timeout: 5), .completed)
        let offlineStatus = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Offline")).firstMatch
        if !offlineStatus.exists { app.swipeDown() }
        XCTAssertTrue(offlineStatus.waitForExistence(timeout: 5))
        app.navigationBars.buttons["New card"].tap()
        let title = app.descendants(matching: .any)["card-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Native offline acceptance")
        app.navigationBars.buttons["Save"].tap()
        let draft = app.staticTexts["Native offline acceptance"]
        if !draft.exists { app.swipeDown() }
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 change saved on this device"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Offline card saved on device"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
        // The next process reconnects and resends the atomically saved outbox.
        app.launch()
        XCTAssertTrue(app.staticTexts["Live"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Native offline acceptance"].waitForExistence(timeout: 5))
        let synced = XCTAttachment(screenshot: app.screenshot())
        synced.name = "Pending card confirmed after relaunch"
        synced.lifetime = .keepAlways
        add(synced)
        // Read the authoritative snapshot through a separate protocol client.
        let socket = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:3090/ws")!)
        socket.resume()
        defer { socket.cancel(with: .goingAway, reason: nil) }
        let join = try JSONSerialization.data(withJSONObject: ["type": "join", "boardId": boardID, "clientId": "uiAcceptanceClient", "name": "Acceptance"])
        try await socket.send(.string(String(decoding: join, as: UTF8.self)))
        let frame = try await socket.receive()
        let payload: Data
        switch frame {
        case .string(let value): payload = Data(value.utf8)
        case .data(let value): payload = value
        @unknown default: throw URLError(.cannotParseResponse)
        }
        let snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let state = try XCTUnwrap(snapshot["state"] as? [String: Any])
        let cards = try XCTUnwrap(state["cards"] as? [[String: Any]])
        XCTAssertEqual(cards.filter { $0["title"] as? String == "Native offline acceptance" }.count, 1)
        // A new native process is not allowed to lose the pending intent on startup.
        XCTAssertFalse(app.staticTexts["1 change saved on this device"].waitForExistence(timeout: 2))
    }
}
