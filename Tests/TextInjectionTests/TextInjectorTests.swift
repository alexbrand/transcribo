import Testing
@testable import TextInjection

/// Mock keyboard driver that records all operations instead of posting real events.
final class MockKeyboardDriver: KeyboardDriver {
    var typedScalars: [Unicode.Scalar] = []
    var deletedCounts: [Int] = []

    func typeCharacter(_ scalar: Unicode.Scalar) {
        typedScalars.append(scalar)
    }

    func deleteCharacters(_ count: Int) {
        deletedCounts.append(count)
    }

    /// The full typed string so far.
    var typedString: String {
        String(typedScalars.map { Character($0) })
    }

    /// Total characters deleted across all delete calls.
    var totalDeleted: Int {
        deletedCounts.reduce(0, +)
    }

    func reset() {
        typedScalars.removeAll()
        deletedCounts.removeAll()
    }
}

// MARK: - TextInjector

@Suite("TextInjector")
struct TextInjectorTests {
    @Test("Initializes with zero partial length")
    func initialization() {
        let injector = TextInjector(driver: MockKeyboardDriver())
        #expect(injector.partialLength == 0)
    }

    @Test("insertText types each character")
    func insertTypesCharacters() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        injector.insertText("hello")

        #expect(mock.typedString == "hello")
        #expect(mock.deletedCounts.isEmpty)
    }

    @Test("insertText sets partialLength to text count")
    func insertSetsPartialLength() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        injector.insertText("hey")
        #expect(injector.partialLength == 3)
    }

    @Test("Second insertText deletes previous partial before typing")
    func secondInsertDeletesPrevious() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        injector.insertText("hel")
        #expect(injector.partialLength == 3)
        #expect(mock.deletedCounts.isEmpty)

        mock.reset()
        injector.insertText("hello")

        // Should have deleted 3 chars (previous partial), then typed 5
        #expect(mock.deletedCounts == [3])
        #expect(mock.typedString == "hello")
        #expect(injector.partialLength == 5)
    }

    @Test("commitText resets partialLength to zero")
    func commitResetsPartial() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        injector.insertText("hello")
        #expect(injector.partialLength == 5)

        injector.commitText()
        #expect(injector.partialLength == 0)
    }

    @Test("insertText after commit does not delete anything")
    func insertAfterCommitNoDelete() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        injector.insertText("first")
        injector.commitText()

        mock.reset()
        injector.insertText("second")

        #expect(mock.deletedCounts.isEmpty)
        #expect(mock.typedString == "second")
    }

    @Test("Multiple partial corrections chain correctly")
    func multiplePartialCorrections() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        // Simulate streaming: "h" → "he" → "hel" → "hello"
        injector.insertText("h")
        #expect(injector.partialLength == 1)

        injector.insertText("he")
        #expect(injector.partialLength == 2)

        injector.insertText("hel")
        #expect(injector.partialLength == 3)

        injector.insertText("hello")
        #expect(injector.partialLength == 5)

        // Verify delete counts: no delete for first, then 1, 2, 3
        #expect(mock.deletedCounts == [1, 2, 3])
    }

    @Test("Empty string insertion sets partialLength to zero")
    func emptyInsert() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        injector.insertText("")
        #expect(injector.partialLength == 0)
        #expect(mock.typedScalars.isEmpty)
    }

    @Test("Empty insert after partial triggers delete but types nothing")
    func emptyInsertAfterPartial() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        injector.insertText("abc")
        mock.reset()

        injector.insertText("")
        #expect(mock.deletedCounts == [3])
        #expect(mock.typedScalars.isEmpty)
        #expect(injector.partialLength == 0)
    }

    @Test("Unicode text tracks character count correctly")
    func unicodePartialLength() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        let text = "café"
        injector.insertText(text)
        #expect(injector.partialLength == text.count)
    }

    @Test("Emoji text tracks character count correctly")
    func emojiPartialLength() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        injector.insertText("hi 👋")
        // "hi 👋" is 4 characters in Swift
        #expect(injector.partialLength == 4)
    }

    @Test("commitText is idempotent")
    func doubleCommit() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        injector.insertText("test")
        injector.commitText()
        injector.commitText()
        #expect(injector.partialLength == 0)
    }

    @Test("Full session: partial → partial → commit → new partial")
    func fullSession() {
        let mock = MockKeyboardDriver()
        let injector = TextInjector(driver: mock)

        // First word: partial corrections
        injector.insertText("th")
        injector.insertText("the")
        injector.commitText()

        // Second word: fresh start
        mock.reset()
        injector.insertText("cat")

        #expect(mock.deletedCounts.isEmpty) // no delete after commit
        #expect(mock.typedString == "cat")
        #expect(injector.partialLength == 3)
    }
}
