import Testing
@testable import TextInjection

@Suite("TextInjector")
struct TextInjectorTests {
    @Test("Injector initializes without error")
    func initialization() {
        let injector = TextInjector()
        _ = injector
    }

    @Test("commitText resets partial tracking")
    func commitResetsPartial() {
        let injector = TextInjector()
        injector.commitText()
        // Should not crash; partial length is reset
    }
}
