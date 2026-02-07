/// Data handling protocols for HL7kit
///
/// This module defines protocols for parsing, serialization, and data transformation
/// across all HL7 standards.

import Foundation

/// Protocol for types that can be parsed from raw data
public protocol Parseable: Sendable {
    /// Parse from raw data
    /// - Parameter data: Raw data to parse
    /// - Returns: Parsed instance
    /// - Throws: HL7Error if parsing fails
    static func parse(from data: Data) throws -> Self
    
    /// Parse from string representation
    /// - Parameter string: String to parse
    /// - Returns: Parsed instance
    /// - Throws: HL7Error if parsing fails
    static func parse(from string: String) throws -> Self
}

/// Protocol for types that can be serialized to raw data
public protocol Serializable: Sendable {
    /// Serialize to raw data
    /// - Returns: Serialized data
    /// - Throws: HL7Error if serialization fails
    func serialize() throws -> Data
    
    /// Serialize to string representation
    /// - Returns: Serialized string
    /// - Throws: HL7Error if serialization fails
    func serializeToString() throws -> String
}

/// Protocol for types that are both parseable and serializable
public protocol DataConvertible: Parseable, Serializable {
}

/// Protocol for transforming data from one format to another
public protocol DataTransformer: Sendable {
    associatedtype Input
    associatedtype Output
    
    /// Transform input data to output data
    /// - Parameter input: Input data
    /// - Returns: Transformed output data
    /// - Throws: HL7Error if transformation fails
    func transform(_ input: Input) throws -> Output
}

/// Options for parsing operations
public struct ParseOptions: Sendable {
    /// Whether to perform strict parsing
    public let strict: Bool
    
    /// Whether to validate during parsing
    public let validate: Bool
    
    /// Character encoding to use
    public let encoding: String.Encoding
    
    /// Whether to preserve whitespace
    public let preserveWhitespace: Bool
    
    public init(
        strict: Bool = false,
        validate: Bool = true,
        encoding: String.Encoding = .utf8,
        preserveWhitespace: Bool = false
    ) {
        self.strict = strict
        self.validate = validate
        self.encoding = encoding
        self.preserveWhitespace = preserveWhitespace
    }
    
    /// Default parse options
    public static let `default` = ParseOptions()
    
    /// Strict parse options
    public static let strict = ParseOptions(strict: true)
}

/// Options for serialization operations
public struct SerializeOptions: Sendable {
    /// Character encoding to use
    public let encoding: String.Encoding
    
    /// Whether to format output for readability
    public let prettyPrint: Bool
    
    /// Whether to validate before serialization
    public let validate: Bool
    
    /// Line ending style
    public let lineEnding: LineEnding
    
    public init(
        encoding: String.Encoding = .utf8,
        prettyPrint: Bool = false,
        validate: Bool = true,
        lineEnding: LineEnding = .lf
    ) {
        self.encoding = encoding
        self.prettyPrint = prettyPrint
        self.validate = validate
        self.lineEnding = lineEnding
    }
    
    /// Default serialize options
    public static let `default` = SerializeOptions()
    
    /// Pretty print serialize options
    public static let prettyPrint = SerializeOptions(prettyPrint: true)
}

/// Line ending styles for serialization
public enum LineEnding: String, Sendable {
    case lf = "\n"
    case crlf = "\r\n"
    case cr = "\r"
}

/// Protocol for lazy parsing strategies
public protocol LazyParseable: Sendable {
    /// The type of raw data held
    associatedtype RawData
    
    /// The parsed type
    associatedtype Parsed
    
    /// Get the raw data without parsing
    var rawData: RawData { get }
    
    /// Parse and return the data
    /// - Returns: Parsed data
    /// - Throws: HL7Error if parsing fails
    func parsed() throws -> Parsed
    
    /// Check if data has been parsed
    var isParsed: Bool { get }
}

/// Protocol for streaming parsers
public protocol StreamingParser: Sendable {
    associatedtype Element
    
    /// Parse the next element from the stream
    /// - Returns: The next element, or nil if stream is exhausted
    /// - Throws: HL7Error if parsing fails
    mutating func next() throws -> Element?
    
    /// Check if more elements are available
    var hasMore: Bool { get }
}

/// Protocol for batch processing
public protocol BatchProcessor: Sendable {
    associatedtype Item
    associatedtype Result
    
    /// Process a batch of items
    /// - Parameter items: Items to process
    /// - Returns: Processing results
    /// - Throws: HL7Error if processing fails
    func processBatch(_ items: [Item]) throws -> [Result]
}
