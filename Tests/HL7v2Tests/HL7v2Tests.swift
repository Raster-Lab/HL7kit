import Testing
import Foundation
@testable import HL7v2
import HL7Core

// MARK: - Sample Messages

private let sampleADT = """
MSH|^~\\&|EPIC|HOSPITAL|LAB|LAB|202401011200||ADT^A04|00001|P|2.5\r\
PID|1||12345^^^MRN||DOE^JOHN^A||19800101|M|||123 FAKE ST^^CITY^ST^12345||555-1234\r\
PV1|1|I|W^389^1
"""

private let sampleORU = """
MSH|^~\\&|LAB|HOSPITAL|EHR|HOSPITAL|202401021000||ORU^R01|MSG00002|P|2.5\r\
PID|1||67890^^^MRN||SMITH^JANE||19900515|F\r\
OBR|1|ORD001|RES001|1234^CBC^L|||202401020800\r\
OBX|1|NM|WBC^White Blood Cell Count^L||7.5|10*3/uL|4.5-11.0|N|||F
"""

// MARK: - Message Parsing Tests

@Suite("Message Parsing")
struct MessageParsingTests {
    @Test("Parse ADT message")
    func parseADT() throws {
        let message = try Message(parsing: sampleADT)
        #expect(message.segments.count == 3)
        #expect(message.segments[0].id == "MSH")
        #expect(message.segments[1].id == "PID")
        #expect(message.segments[2].id == "PV1")
    }

    @Test("Parse ORU message")
    func parseORU() throws {
        let message = try Message(parsing: sampleORU)
        #expect(message.segments.count == 4)
    }

    @Test("Empty message throws")
    func emptyThrows() {
        #expect(throws: HL7Core.HL7Error.self) {
            try Message(parsing: "")
        }
    }

    @Test("Non-MSH message throws")
    func nonMSHThrows() {
        #expect(throws: HL7Core.HL7Error.self) {
            try Message(parsing: "PID|1||12345")
        }
    }

    @Test("Message version is parsed")
    func versionParsed() throws {
        let message = try Message(parsing: sampleADT)
        #expect(message.version == .v25)
    }

    @Test("Message type is parsed")
    func messageType() throws {
        let message = try Message(parsing: sampleADT)
        #expect(message.messageType == "ADT^A04")
    }

    @Test("Control ID is parsed")
    func controlID() throws {
        let message = try Message(parsing: sampleADT)
        #expect(message.controlID == "00001")
    }

    @Test("Newline-separated messages parse correctly")
    func newlineSeparated() throws {
        let msg = "MSH|^~\\&|A|B|C|D|202401011200||ADT^A04|1|P|2.5\nPID|1||123"
        let message = try Message(parsing: msg)
        #expect(message.segments.count == 2)
    }
}

// MARK: - Encoding Characters Tests

@Suite("Encoding Characters")
struct EncodingCharactersTests {
    @Test("Standard encoding characters")
    func standardEncoding() {
        let enc = EncodingCharacters.standard
        #expect(enc.fieldSeparator == "|")
        #expect(enc.componentSeparator == "^")
        #expect(enc.repetitionSeparator == "~")
        #expect(enc.escapeCharacter == "\\")
        #expect(enc.subComponentSeparator == "&")
    }

    @Test("Parse from MSH prefix")
    func parseFromMSH() {
        let enc = EncodingCharacters.from(mshPrefix: "MSH|^~\\&|EPIC")
        #expect(enc != nil)
        #expect(enc?.fieldSeparator == "|")
    }

    @Test("Invalid MSH prefix returns nil")
    func invalidMSH() {
        #expect(EncodingCharacters.from(mshPrefix: "PID|1") == nil)
        #expect(EncodingCharacters.from(mshPrefix: "MSH") == nil)
    }
}

// MARK: - Segment Tests

@Suite("Segment")
struct SegmentTests {
    @Test("Segment ID is parsed")
    func segmentID() {
        let seg = Segment("PID|1||12345^^^MRN||DOE^JOHN^A")
        #expect(seg.id == "PID")
    }

    @Test("Field access by index")
    func fieldAccess() {
        let seg = Segment("PID|1||12345^^^MRN||DOE^JOHN^A")
        #expect(seg[field: 1]?.value == "1")
        #expect(seg[field: 3]?.value == "12345")
    }

    @Test("Out of range field returns nil")
    func outOfRange() {
        let seg = Segment("PID|1")
        #expect(seg[field: 99] == nil)
    }

    @Test("MSH field 1 is field separator")
    func mshField1() {
        let seg = Segment("MSH|^~\\&|EPIC|HOSPITAL")
        #expect(seg[field: 1]?.value == "|")
    }
}

// MARK: - Field Tests

@Suite("Field")
struct FieldTests {
    @Test("Simple field value")
    func simpleValue() {
        let field = Field("12345")
        #expect(field.value == "12345")
        #expect(!field.isEmpty)
    }

    @Test("Component access")
    func componentAccess() {
        let field = Field("DOE^JOHN^A")
        #expect(field[component: 1]?.value == "DOE")
        #expect(field[component: 2]?.value == "JOHN")
        #expect(field[component: 3]?.value == "A")
    }

    @Test("Empty field")
    func emptyField() {
        let field = Field("")
        #expect(field.isEmpty)
    }

    @Test("Repetitions")
    func repetitions() {
        let field = Field("VALUE1~VALUE2~VALUE3")
        #expect(field.repetitions.count == 3)
    }
}

// MARK: - Terser Tests

@Suite("Terser")
struct TerserTests {
    @Test("Access segment field")
    func accessField() throws {
        let message = try Message(parsing: sampleADT)
        #expect(message.terser["PID-1"] == "1")
    }

    @Test("Access field component")
    func accessComponent() throws {
        let message = try Message(parsing: sampleADT)
        #expect(message.terser["PID-5-1"] == "DOE")
        #expect(message.terser["PID-5-2"] == "JOHN")
    }

    @Test("Non-existent path returns nil")
    func nonExistent() throws {
        let message = try Message(parsing: sampleADT)
        #expect(message.terser["ZZZ-1"] == nil)
    }

    @Test("Segment repetition")
    func segmentRepetition() throws {
        let message = try Message(parsing: sampleORU)
        // OBX(0) is the first OBX segment
        #expect(message.terser["OBX(0)-1"] == "1")
    }
}

// MARK: - MLLP Framer Tests

@Suite("MLLP Framer")
struct MLLPFramerTests {
    @Test("Frame and unframe round-trip")
    func roundTrip() throws {
        let original = "MSH|^~\\&|A|B|C|D|202401011200||ADT^A04|1|P|2.5\rPID|1||123"
        let framed = MLLPFramer.frame(original)
        let unframed = try MLLPFramer.unframe(framed)
        #expect(unframed == original)
    }

    @Test("Framed data starts with 0x0B")
    func startsWithVT() {
        let framed = MLLPFramer.frame("MSH|test")
        #expect(framed.first == 0x0B)
    }

    @Test("Framed data ends with 0x1C 0x0D")
    func endsCorrectly() {
        let framed = MLLPFramer.frame("MSH|test")
        #expect(framed[framed.count - 2] == 0x1C)
        #expect(framed[framed.count - 1] == 0x0D)
    }

    @Test("Invalid frame throws")
    func invalidFrameThrows() {
        let badData = Data("not a frame".utf8)
        #expect(throws: HL7Core.HL7Error.self) {
            try MLLPFramer.unframe(badData)
        }
    }
}

// MARK: - ER7 Encoding Tests

@Suite("ER7 Encoding")
struct ER7EncodingTests {
    @Test("Encode preserves original")
    func encodePreservesOriginal() throws {
        let message = try Message(parsing: sampleADT)
        let encoded = message.encodeER7()
        // Re-parse should succeed
        let reparsed = try Message(parsing: encoded)
        #expect(reparsed.segments.count == message.segments.count)
    }
}
