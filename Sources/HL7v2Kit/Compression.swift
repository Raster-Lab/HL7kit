/// Compression support for HL7 v2.x messages
///
/// Provides utilities for compressing and decompressing HL7 messages
/// using Foundation's Compression framework.

import Foundation
import HL7Core

#if canImport(Compression)
import Compression
#endif

// MARK: - Compression Algorithm

/// Compression algorithm to use
public enum CompressionAlgorithm: Sendable, Equatable {
    /// LZFSE (Apple's compression algorithm, best compression ratio)
    case lzfse
    /// LZ4 (fast compression/decompression)
    case lz4
    /// ZLIB (industry standard, good compatibility)
    case zlib
    /// LZMA (high compression ratio, slower)
    case lzma
    
    #if canImport(Compression)
    /// Get the Compression framework algorithm
    @available(macOS 10.11, iOS 9.0, *)
    var algorithm: compression_algorithm {
        switch self {
        case .lzfse:
            return COMPRESSION_LZFSE
        case .lz4:
            return COMPRESSION_LZ4
        case .zlib:
            return COMPRESSION_ZLIB
        case .lzma:
            return COMPRESSION_LZMA
        }
    }
    #endif
}

// MARK: - Compression Level

/// Compression level hint
public enum CompressionLevel: Sendable, Equatable {
    /// Fast compression, lower ratio
    case fast
    /// Balanced compression
    case balanced
    /// Best compression ratio, slower
    case best
    
    /// Default compression level for each algorithm
    public static func `default`(for algorithm: CompressionAlgorithm) -> CompressionLevel {
        switch algorithm {
        case .lz4:
            return .fast
        case .lzfse, .zlib:
            return .balanced
        case .lzma:
            return .best
        }
    }
}

// MARK: - Compression Utilities

/// Utilities for compressing and decompressing HL7 messages
public struct CompressionUtilities: Sendable {
    
    /// Compress data using the specified algorithm
    /// - Parameters:
    ///   - data: Data to compress
    ///   - algorithm: Compression algorithm to use
    ///   - level: Compression level hint
    /// - Returns: Compressed data
    /// - Throws: HL7Error if compression fails
    public static func compress(
        _ data: Data,
        algorithm: CompressionAlgorithm = .lzfse,
        level: CompressionLevel = .balanced
    ) throws -> Data {
        #if canImport(Compression)
        guard #available(macOS 10.11, iOS 9.0, *) else {
            throw HL7Error.configurationError("Compression not available on this platform")
        }
        
        return try data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Data in
            guard let sourcePointer = sourceBuffer.baseAddress else {
                throw HL7Error.parsingError("Invalid source data")
            }
            
            let sourceSize = data.count
            let destBufferSize = sourceSize + 1024  // Add buffer for worst case
            var destBuffer = [UInt8](repeating: 0, count: destBufferSize)
            
            let compressedSize = compression_encode_buffer(
                &destBuffer,
                destBufferSize,
                sourcePointer,
                sourceSize,
                nil,
                algorithm.algorithm
            )
            
            guard compressedSize > 0 else {
                throw HL7Error.parsingError("Compression failed")
            }
            
            return Data(destBuffer.prefix(compressedSize))
        }
        #else
        throw HL7Error.configurationError("Compression not available on this platform")
        #endif
    }
    
    /// Decompress data using the specified algorithm
    /// - Parameters:
    ///   - data: Compressed data
    ///   - algorithm: Compression algorithm used
    ///   - maxSize: Maximum expected decompressed size (default 10MB)
    /// - Returns: Decompressed data
    /// - Throws: HL7Error if decompression fails
    public static func decompress(
        _ data: Data,
        algorithm: CompressionAlgorithm = .lzfse,
        maxSize: Int = 10 * 1024 * 1024
    ) throws -> Data {
        #if canImport(Compression)
        guard #available(macOS 10.11, iOS 9.0, *) else {
            throw HL7Error.configurationError("Compression not available on this platform")
        }
        
        return try data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Data in
            guard let sourcePointer = sourceBuffer.baseAddress else {
                throw HL7Error.parsingError("Invalid compressed data")
            }
            
            let sourceSize = data.count
            var destBuffer = [UInt8](repeating: 0, count: maxSize)
            
            let decompressedSize = compression_decode_buffer(
                &destBuffer,
                maxSize,
                sourcePointer,
                sourceSize,
                nil,
                algorithm.algorithm
            )
            
            guard decompressedSize > 0 else {
                throw HL7Error.parsingError("Decompression failed")
            }
            
            return Data(destBuffer.prefix(decompressedSize))
        }
        #else
        throw HL7Error.configurationError("Compression not available on this platform")
        #endif
    }
    
    /// Compress a string
    /// - Parameters:
    ///   - string: String to compress
    ///   - encoding: String encoding to use
    ///   - algorithm: Compression algorithm
    ///   - level: Compression level
    /// - Returns: Compressed data
    /// - Throws: HL7Error if compression fails
    public static func compress(
        _ string: String,
        encoding: String.Encoding = .utf8,
        algorithm: CompressionAlgorithm = .lzfse,
        level: CompressionLevel = .balanced
    ) throws -> Data {
        guard let data = string.data(using: encoding) else {
            throw HL7Error.parsingError("Failed to encode string")
        }
        return try compress(data, algorithm: algorithm, level: level)
    }
    
    /// Decompress to a string
    /// - Parameters:
    ///   - data: Compressed data
    ///   - encoding: String encoding to use
    ///   - algorithm: Compression algorithm used
    ///   - maxSize: Maximum expected decompressed size
    /// - Returns: Decompressed string
    /// - Throws: HL7Error if decompression fails
    public static func decompressToString(
        _ data: Data,
        encoding: String.Encoding = .utf8,
        algorithm: CompressionAlgorithm = .lzfse,
        maxSize: Int = 10 * 1024 * 1024
    ) throws -> String {
        let decompressedData = try decompress(data, algorithm: algorithm, maxSize: maxSize)
        guard let string = String(data: decompressedData, encoding: encoding) else {
            throw HL7Error.parsingError("Failed to decode decompressed data")
        }
        return string
    }
    
    /// Calculate compression ratio
    /// - Parameters:
    ///   - original: Original data size
    ///   - compressed: Compressed data size
    /// - Returns: Compression ratio (e.g., 0.5 means 50% of original size)
    public static func compressionRatio(original: Int, compressed: Int) -> Double {
        guard original > 0 else { return 0.0 }
        return Double(compressed) / Double(original)
    }
}

// MARK: - Compressed Message

/// A compressed HL7 message with metadata
public struct CompressedMessage: Sendable, Equatable {
    /// Compressed data
    public let data: Data
    /// Compression algorithm used
    public let algorithm: CompressionAlgorithm
    /// Original message size in bytes
    public let originalSize: Int
    /// Compressed message size in bytes
    public var compressedSize: Int {
        data.count
    }
    /// Compression ratio
    public var compressionRatio: Double {
        CompressionUtilities.compressionRatio(original: originalSize, compressed: compressedSize)
    }
    
    /// Initialize compressed message
    public init(data: Data, algorithm: CompressionAlgorithm, originalSize: Int) {
        self.data = data
        self.algorithm = algorithm
        self.originalSize = originalSize
    }
}

// MARK: - Message Compression Extensions

extension HL7v2Message {
    /// Compress the message
    /// - Parameters:
    ///   - algorithm: Compression algorithm to use
    ///   - level: Compression level
    /// - Returns: Compressed message
    /// - Throws: HL7Error if compression fails
    public func compress(
        algorithm: CompressionAlgorithm = .lzfse,
        level: CompressionLevel = .balanced
    ) throws -> CompressedMessage {
        let serialized = try serialize()
        guard let data = serialized.data(using: .utf8) else {
            throw HL7Error.parsingError("Failed to encode message")
        }
        
        let compressedData = try CompressionUtilities.compress(
            data,
            algorithm: algorithm,
            level: level
        )
        
        return CompressedMessage(
            data: compressedData,
            algorithm: algorithm,
            originalSize: data.count
        )
    }
}

extension HL7v2Parser {
    /// Parse a compressed message
    /// - Parameters:
    ///   - compressed: Compressed message
    ///   - maxSize: Maximum expected decompressed size
    /// - Returns: Parsed message
    /// - Throws: HL7Error if decompression or parsing fails
    public func parseCompressed(
        _ compressed: CompressedMessage,
        maxSize: Int = 10 * 1024 * 1024
    ) throws -> HL7v2Message {
        let messageString = try CompressionUtilities.decompressToString(
            compressed.data,
            encoding: configuration.encoding.stringEncoding,
            algorithm: compressed.algorithm,
            maxSize: maxSize
        )
        
        return try parse(messageString)
    }
    
    /// Parse compressed data
    /// - Parameters:
    ///   - data: Compressed data
    ///   - algorithm: Compression algorithm used
    ///   - maxSize: Maximum expected decompressed size
    /// - Returns: Parsed message
    /// - Throws: HL7Error if decompression or parsing fails
    public func parseCompressed(
        _ data: Data,
        algorithm: CompressionAlgorithm = .lzfse,
        maxSize: Int = 10 * 1024 * 1024
    ) throws -> HL7v2Message {
        let messageString = try CompressionUtilities.decompressToString(
            data,
            encoding: configuration.encoding.stringEncoding,
            algorithm: algorithm,
            maxSize: maxSize
        )
        
        return try parse(messageString)
    }
}

// MARK: - Batch Compression Extensions

extension BatchMessage {
    /// Compress the batch
    /// - Parameters:
    ///   - algorithm: Compression algorithm to use
    ///   - level: Compression level
    /// - Returns: Compressed batch data with metadata
    /// - Throws: HL7Error if compression fails
    public func compress(
        algorithm: CompressionAlgorithm = .lzfse,
        level: CompressionLevel = .balanced
    ) throws -> CompressedMessage {
        let serialized = try serialize()
        guard let data = serialized.data(using: .utf8) else {
            throw HL7Error.parsingError("Failed to encode batch")
        }
        
        let compressedData = try CompressionUtilities.compress(
            data,
            algorithm: algorithm,
            level: level
        )
        
        return CompressedMessage(
            data: compressedData,
            algorithm: algorithm,
            originalSize: data.count
        )
    }
}

extension FileMessage {
    /// Compress the file
    /// - Parameters:
    ///   - algorithm: Compression algorithm to use
    ///   - level: Compression level
    /// - Returns: Compressed file data with metadata
    /// - Throws: HL7Error if compression fails
    public func compress(
        algorithm: CompressionAlgorithm = .lzfse,
        level: CompressionLevel = .balanced
    ) throws -> CompressedMessage {
        let serialized = try serialize()
        guard let data = serialized.data(using: .utf8) else {
            throw HL7Error.parsingError("Failed to encode file")
        }
        
        let compressedData = try CompressionUtilities.compress(
            data,
            algorithm: algorithm,
            level: level
        )
        
        return CompressedMessage(
            data: compressedData,
            algorithm: algorithm,
            originalSize: data.count
        )
    }
}
