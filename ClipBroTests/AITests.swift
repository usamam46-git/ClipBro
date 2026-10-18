import Foundation

final class MockProtocol: URLProtocol, @unchecked Sendable {
    static var status = 200
    static var body = Data()
    static var requests = 0
    static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1; Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct AITests {
    static var checks = 0
    static func check(_ value: Bool, _ name: String) { precondition(value, name); checks += 1; print("PASS: \(name)") }
    static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockProtocol.self]
        let service = AIService(session: URLSession(configuration: configuration))
        var prefs = Preferences()
        let action = AIAction.all[0]
        do { _ = try await service.transform(text: "fixture", action: action, preferences: prefs, key: "test-fixture"); fatalError("disabled accepted") }
        catch { check(error as? AIError == .disabled && MockProtocol.requests == 0, "local-only blocks network") }
        prefs.aiEnabled = true
        do { _ = try await service.transform(text: "fixture", action: action, preferences: prefs, key: ""); fatalError("missing key accepted") }
        catch { check(error as? AIError == .missingKey && MockProtocol.requests == 0, "missing key blocks network") }
        do { _ = try await service.transform(text: String(repeating: "a", count: 24_001), action: action, preferences: prefs, key: "test-fixture"); fatalError("long input accepted") }
        catch { check(error as? AIError == .tooLong && MockProtocol.requests == 0, "input cap blocks network") }
        MockProtocol.body = Data(#"{"status":"completed","output":[{"type":"reasoning"},{"type":"message","content":[{"type":"output_text","text":"Corrected fixture."}]}]}"#.utf8)
        let result = try await service.transform(text: "fixture", action: action, preferences: prefs, key: "test-fixture")
        check(result == "Corrected fixture.", "Responses API output parsed")
        check(MockProtocol.lastRequest?.url?.host == "api.openai.com", "fixed official HTTPS endpoint")
        for status in [401, 429, 500] {
            MockProtocol.status = status
            do { _ = try await service.transform(text: "fixture", action: action, preferences: prefs, key: "test-fixture"); fatalError("HTTP error accepted") }
            catch { check(error as? AIError == .http(status), "HTTP \(status) handled") }
        }
        for (body, expected) in [("invalid", AIError.malformed), (#"{"status":"completed","output":[]}"#, .empty), (#"{"status":"incomplete","output":[]}"#, .incomplete)] {
            do { _ = try AIService.decode(Data(body.utf8)); fatalError("bad response accepted") }
            catch { check(error as? AIError == expected, "response failure \(expected)") }
        }
        check(Set(AIAction.all.map(\.id)).count == AIAction.all.count && AIAction.all.count == 25, "all actions have unique identities")
        print("\(checks) AI checks passed; no external requests")
    }
}
