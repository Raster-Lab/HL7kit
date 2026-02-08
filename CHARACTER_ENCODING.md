# Character Encoding Support in HL7v2Kit

## Overview

HL7v2Kit provides comprehensive support for multiple character encodings in HL7 v2.x messages, including automatic encoding detection, MSH-18 field processing, and encoding validation.

## Supported Character Sets

HL7v2Kit supports the following HL7 standard character sets (HL7 Table 0211):

### ASCII Variants
- `ASCII` - 7-bit ASCII
- `ISO IR6` - ISO ASCII

### ISO 8859 Series (Latin)
- `8859/1` - Latin-1 (Western European)
- `8859/2` - Latin-2 (Central European)
- `8859/3` - Latin-3 (South European)
- `8859/4` - Latin-4 (North European)
- `8859/5` - Cyrillic
- `8859/6` - Arabic
- `8859/7` - Greek
- `8859/8` - Hebrew
- `8859/9` - Latin-5 (Turkish)
- `8859/15` - Latin-9 (adds Euro sign)

### ISO IR Series
- `ISO IR100` - Latin-1
- `ISO IR101` - Latin-2
- `ISO IR109` - Latin-3
- `ISO IR110` - Latin-4
- `ISO IR144` - Cyrillic
- `ISO IR127` - Arabic
- `ISO IR126` - Greek
- `ISO IR138` - Hebrew
- `ISO IR148` - Latin-5 (Turkish)
- `ISO IR192` - UTF-8

### UNICODE
- `UNICODE` - Typically implies UTF-16
- `UNICODE UTF-8` - Explicit UTF-8
- `UNICODE UTF-16` - Explicit UTF-16

### East Asian Encodings
- `ISO IR87` - Japanese Katakana
- `ISO IR159` - Japanese JIS X 0212-1990
- `GB 18030` - Chinese
- `KS X 1001` - Korean
- `CNS 11643-1992` - Taiwanese
- `BIG-5` - Traditional Chinese

## Usage

### Basic Parsing with Encoding Detection

```swift
import HL7v2Kit

let parser = HL7v2Parser()
let message = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5|||||||UNICODE UTF-8\rPID|||12345^^^MRN||Smith^John||19800101|M"

let result = try parser.parse(message)
let msg = result.message

// Get character sets from MSH-18
let charsets = msg.characterSets()
print("Message uses character set: \(charsets.first?.rawValue ?? "none specified")")
// Output: "Message uses character set: UNICODE UTF-8"
```

### Getting Primary Encoding

```swift
// Get the primary character set
if let primaryCharset = msg.primaryCharacterSet() {
    print("Primary charset: \(primaryCharset.rawValue)")
}

// Get the corresponding MessageEncoding
if let encoding = msg.primaryEncoding() {
    print("Primary encoding: \(encoding)")
}
```

### Parsing with Specific Encoding

```swift
let config = ParserConfiguration(
    encoding: .utf8,
    validateEncoding: true  // Enable encoding validation
)
let parser = HL7v2Parser(configuration: config)
let result = try parser.parse(messageData)

// Check for encoding warnings
for warning in result.diagnostics.warnings {
    if warning.message.contains("Encoding mismatch") {
        print("Warning: \(warning.message)")
    }
}
```

### Respecting MSH-18 Field

By default, the parser respects the MSH-18 field:

```swift
let config = ParserConfiguration(
    respectMSH18: true,      // Default: true
    validateEncoding: true   // Default: false
)
```

When `respectMSH18` is enabled:
- The parser will use the character set specified in MSH-18 if present
- If MSH-18 is empty, the parser uses the configured encoding
- If MSH-18 specifies an unsupported character set, a warning is generated

### Encoding Validation

Enable encoding validation to detect mismatches:

```swift
let config = ParserConfiguration(
    encoding: .utf8,
    validateEncoding: true
)
let parser = HL7v2Parser(configuration: config)
let result = try parser.parse(message)

// Check diagnostics for encoding issues
if !result.diagnostics.warnings.isEmpty {
    for warning in result.diagnostics.warnings {
        print("Warning: \(warning.message)")
    }
}
```

Validation checks for:
- **Encoding mismatches**: Used encoding differs from MSH-18 declaration
- **Unsupported character sets**: MSH-18 specifies a character set not directly supported
- **Multiple character sets**: Message declares multiple character sets (limited support)

### Handling Multiple Character Sets

HL7 allows messages to specify multiple character sets in MSH-18 using repetitions:

```swift
let message = "MSH|^~\\&|...|...|...|...|...|...|...|...|...|...|||||||ASCII~UNICODE UTF-8\r..."

let result = try parser.parse(message)
let msg = result.message

let charsets = msg.characterSets()
// charsets contains [.ascii, .unicodeUTF8]

print("Message uses \(charsets.count) character sets")
for charset in charsets {
    print("  - \(charset.rawValue)")
}
```

**Note**: Full multi-encoding support within a single message is limited. The parser will generate a warning when multiple character sets are declared.

## Character Set Mapping

### CharacterSet to MessageEncoding

Not all HL7 character sets map directly to the MessageEncoding enum:

| HL7 Character Set | MessageEncoding | Supported |
|-------------------|----------------|-----------|
| ASCII, ISO IR6 | .ascii | ✓ |
| 8859/1, ISO IR100 | .latin1 | ✓ |
| ISO IR192, UNICODE UTF-8 | .utf8 | ✓ |
| UNICODE, UNICODE UTF-16 | .utf16 | ✓ |
| 8859/2, 8859/5-9 | nil | Partial* |
| GB 18030, BIG-5 | nil | Limited |

*Partial support on Apple platforms via CoreFoundation

### CharacterSet to String.Encoding

The `toStringEncoding()` method provides broader support on Apple platforms:

```swift
let charset = CharacterSet.iso88592 // Latin-2

if let encoding = charset.toStringEncoding() {
    // Use native String.Encoding for decoding
    let text = String(data: data, encoding: encoding)
}
```

## Best Practices

### 1. Use Auto-Detection for Unknown Sources

```swift
let config = ParserConfiguration(encoding: .autoDetect)
let parser = HL7v2Parser(configuration: config)
```

### 2. Enable Validation in Production

```swift
let config = ParserConfiguration(
    encoding: .utf8,
    validateEncoding: true
)
```

### 3. Handle Encoding Warnings

```swift
let result = try parser.parse(message)

for warning in result.diagnostics.warnings {
    if warning.message.contains("character set") ||
       warning.message.contains("Encoding mismatch") {
        logger.warning("Encoding issue: \(warning.message)")
    }
}
```

### 4. Explicitly Set Character Set When Creating Messages

```swift
let builder = HL7v2MessageBuilder()
    .addMSHSegment { msh in
        msh.sendingApplication("MyApp")
            .messageType("ADT", triggerEvent: "A01")
            .version("2.5")
            // ... other fields ...
            .setField(18, value: "UNICODE UTF-8")  // MSH-18
    }
```

### 5. Test with Multiple Encodings

Always test your message handling with:
- Pure ASCII messages
- UTF-8 messages with international characters
- Latin-1 messages with extended characters
- Messages with missing MSH-18

## Performance Considerations

- Encoding detection (`MessageEncoding.detect(from:)`) is fast and optimized
- Character set parsing from MSH-18 is performed once during message parsing
- No performance impact when `validateEncoding` is disabled
- Validation adds minimal overhead (< 1% parsing time)

## Platform Differences

### Apple Platforms (macOS, iOS, etc.)
- Full support for all ISO 8859 variants via CoreFoundation
- Native compression framework support
- Optimal performance

### Linux
- Core encodings supported: ASCII, UTF-8, UTF-16, Latin-1, Latin-2
- Extended ISO 8859 variants may have limited support
- No compression framework (platform-specific features)

## Error Handling

### Encoding Errors

```swift
do {
    let result = try parser.parse(data)
} catch let error as HL7Error {
    switch error {
    case .encodingError(let message):
        print("Encoding error: \(message)")
    case .parsingError(let message):
        print("Parsing error: \(message)")
    default:
        print("Other error: \(error)")
    }
}
```

### Warnings vs Errors

- **Errors**: Thrown when parsing cannot continue (e.g., invalid data for configured encoding)
- **Warnings**: Collected in diagnostics for informational purposes (e.g., encoding mismatch, unsupported character set)

## Examples

### Example 1: Parse UTF-8 Message

```swift
let message = """
MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5|||||||UNICODE UTF-8\r\
PID|||12345^^^MRN||Müller^José||19800101|M\r\
PV1||I|ICU
"""

let parser = HL7v2Parser()
let result = try parser.parse(message)

print("Primary encoding: \(result.message.primaryEncoding() ?? .utf8)")
// Output: "Primary encoding: utf8"
```

### Example 2: Validate Encoding Declaration

```swift
let config = ParserConfiguration(
    encoding: .latin1,
    validateEncoding: true
)
let parser = HL7v2Parser(configuration: config)

// Message declares UTF-8 but we're using Latin-1
let result = try parser.parse(messageWithUTF8Declaration)

// Check for mismatch warning
let hasMismatch = result.diagnostics.warnings.contains { warning in
    warning.message.contains("Encoding mismatch")
}
print("Has encoding mismatch: \(hasMismatch)")
// Output: "Has encoding mismatch: true"
```

### Example 3: Handle Unsupported Character Set

```swift
let message = """
MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5|||||||GB 18030\r\
PID|||12345^^^MRN||王^小明||19800101|M
"""

let config = ParserConfiguration(validateEncoding: true)
let parser = HL7v2Parser(configuration: config)
let result = try parser.parse(message)

// GB 18030 is recognized but not directly supported
let charset = result.message.primaryCharacterSet()
print("Character set: \(charset?.rawValue ?? "none")")
// Output: "Character set: GB 18030"

let encoding = result.message.primaryEncoding()
print("Encoding: \(encoding?.description ?? "not mappable")")
// Output: "Encoding: not mappable"

// Check for unsupported warning
for warning in result.diagnostics.warnings {
    print("Warning: \(warning.message)")
}
// Output: "Warning: MSH-18 character set 'GB 18030' is not directly supported"
```

## Testing

HL7v2Kit includes comprehensive tests for character encoding support:

```bash
swift test --filter CharacterEncodingTests
```

Test coverage includes:
- Character set parsing (32 tests)
- MSH-18 field extraction
- Encoding validation
- Multiple character sets
- Round-trip encoding/decoding
- Edge cases and error handling

## References

- HL7 Table 0211: Alternate Character Sets
- HL7 v2.x Implementation Guide, Chapter 2.A: Character Sets
- RFC 3629: UTF-8, a transformation format of ISO 10646
- ISO/IEC 8859 series: 8-bit single-byte coded graphic character sets
