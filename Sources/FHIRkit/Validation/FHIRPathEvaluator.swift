/// FHIRPathEvaluator.swift
/// FHIRPath expression evaluation for FHIR resource validation
///
/// Implements a subset of the FHIRPath specification sufficient for
/// evaluating common FHIR invariants and constraints. Supports
/// path navigation, existence checks, boolean logic, string operations,
/// and type checking.

import Foundation
import HL7Core

// MARK: - FHIRPath Token

/// Token types for FHIRPath lexing
public enum FHIRPathTokenType: Sendable, Equatable {
    case identifier(String)
    case stringLiteral(String)
    case numberLiteral(String)
    case booleanLiteral(Bool)
    case dot
    case openParen
    case closeParen
    case and
    case or
    case not
    case equals
    case notEquals
    case greaterThan
    case lessThan
    case greaterThanOrEqual
    case lessThanOrEqual
    case plus
    case pipe
    case `where`
    case exists
    case empty
    case count
    case `as`
    case `is`
    case all
    case hasValue
    case startsWith
    case endsWith
    case contains
    case matches
    case length
    case implies
    case xor
    case eof
}

/// A FHIRPath token
public struct FHIRPathToken: Sendable, Equatable {
    public let type: FHIRPathTokenType
    public let position: Int

    public init(type: FHIRPathTokenType, position: Int = 0) {
        self.type = type
        self.position = position
    }
}

// MARK: - FHIRPath Tokenizer

/// Tokenizes FHIRPath expressions
public struct FHIRPathTokenizer: Sendable {

    public init() {}

    /// Tokenize a FHIRPath expression
    public func tokenize(_ expression: String) -> [FHIRPathToken] {
        var tokens: [FHIRPathToken] = []
        var chars = Array(expression)
        var pos = 0

        while pos < chars.count {
            let ch = chars[pos]

            // Skip whitespace
            if ch.isWhitespace {
                pos += 1
                continue
            }

            // String literal
            if ch == "'" {
                let start = pos
                pos += 1
                var value = ""
                while pos < chars.count && chars[pos] != "'" {
                    if chars[pos] == "\\" && pos + 1 < chars.count {
                        pos += 1
                        value.append(chars[pos])
                    } else {
                        value.append(chars[pos])
                    }
                    pos += 1
                }
                pos += 1 // Skip closing quote
                tokens.append(FHIRPathToken(type: .stringLiteral(value), position: start))
                continue
            }

            // Number literal
            if ch.isNumber || (ch == "-" && pos + 1 < chars.count && chars[pos + 1].isNumber) {
                let start = pos
                var numStr = String(ch)
                pos += 1
                while pos < chars.count && (chars[pos].isNumber || chars[pos] == ".") {
                    numStr.append(chars[pos])
                    pos += 1
                }
                tokens.append(FHIRPathToken(type: .numberLiteral(numStr), position: start))
                continue
            }

            // Operators and punctuation
            switch ch {
            case ".":
                tokens.append(FHIRPathToken(type: .dot, position: pos))
                pos += 1
            case "(":
                tokens.append(FHIRPathToken(type: .openParen, position: pos))
                pos += 1
            case ")":
                tokens.append(FHIRPathToken(type: .closeParen, position: pos))
                pos += 1
            case "+":
                tokens.append(FHIRPathToken(type: .plus, position: pos))
                pos += 1
            case "|":
                tokens.append(FHIRPathToken(type: .pipe, position: pos))
                pos += 1
            case "=":
                tokens.append(FHIRPathToken(type: .equals, position: pos))
                pos += 1
            case "!":
                if pos + 1 < chars.count && chars[pos + 1] == "=" {
                    tokens.append(FHIRPathToken(type: .notEquals, position: pos))
                    pos += 2
                } else {
                    tokens.append(FHIRPathToken(type: .not, position: pos))
                    pos += 1
                }
            case ">":
                if pos + 1 < chars.count && chars[pos + 1] == "=" {
                    tokens.append(FHIRPathToken(type: .greaterThanOrEqual, position: pos))
                    pos += 2
                } else {
                    tokens.append(FHIRPathToken(type: .greaterThan, position: pos))
                    pos += 1
                }
            case "<":
                if pos + 1 < chars.count && chars[pos + 1] == "=" {
                    tokens.append(FHIRPathToken(type: .lessThanOrEqual, position: pos))
                    pos += 2
                } else {
                    tokens.append(FHIRPathToken(type: .lessThan, position: pos))
                    pos += 1
                }
            default:
                // Identifier or keyword
                if ch.isLetter || ch == "_" {
                    let start = pos
                    var ident = ""
                    while pos < chars.count && (chars[pos].isLetter || chars[pos].isNumber || chars[pos] == "_") {
                        ident.append(chars[pos])
                        pos += 1
                    }
                    let tokenType = keywordType(for: ident)
                    tokens.append(FHIRPathToken(type: tokenType, position: start))
                } else {
                    // Unknown character - skip
                    pos += 1
                }
            }
        }

        tokens.append(FHIRPathToken(type: .eof, position: pos))
        return tokens
    }

    private func keywordType(for identifier: String) -> FHIRPathTokenType {
        switch identifier {
        case "and": return .and
        case "or": return .or
        case "not": return .not
        case "true": return .booleanLiteral(true)
        case "false": return .booleanLiteral(false)
        case "where": return .where
        case "exists": return .exists
        case "empty": return .empty
        case "count": return .count
        case "as": return .as
        case "is": return .is
        case "all": return .all
        case "hasValue": return .hasValue
        case "startsWith": return .startsWith
        case "endsWith": return .endsWith
        case "contains": return .contains
        case "matches": return .matches
        case "length": return .length
        case "implies": return .implies
        case "xor": return .xor
        default: return .identifier(identifier)
        }
    }
}

// MARK: - FHIRPath Value

/// A value in FHIRPath evaluation
public enum FHIRPathValue: Sendable, Equatable {
    case string(String)
    case integer(Int)
    case decimal(Double)
    case boolean(Bool)
    case dateTime(String)
    case collection([FHIRPathValue])
    case empty

    /// Convert to boolean for truthiness
    public var isTruthy: Bool {
        switch self {
        case .boolean(let val): return val
        case .string(let val): return !val.isEmpty
        case .integer(let val): return val != 0
        case .decimal(let val): return val != 0
        case .collection(let vals): return !vals.isEmpty
        case .dateTime: return true
        case .empty: return false
        }
    }

    /// Convert to string representation
    public var stringValue: String? {
        switch self {
        case .string(let val): return val
        case .integer(let val): return String(val)
        case .decimal(let val): return String(val)
        case .boolean(let val): return String(val)
        case .dateTime(let val): return val
        case .collection(let vals):
            if vals.count == 1 { return vals[0].stringValue }
            return nil
        case .empty: return nil
        }
    }

    /// Convert to integer
    public var intValue: Int? {
        switch self {
        case .integer(let val): return val
        case .string(let val): return Int(val)
        case .decimal(let val): return Int(val)
        case .collection(let vals):
            if vals.count == 1 { return vals[0].intValue }
            return nil
        default: return nil
        }
    }
}

// MARK: - FHIRPath Evaluator

/// Evaluates FHIRPath expressions against resource data
public struct FHIRPathEvaluator: Sendable {
    private let tokenizer: FHIRPathTokenizer

    public init() {
        self.tokenizer = FHIRPathTokenizer()
    }

    /// Evaluate a FHIRPath expression against resource data
    /// - Parameters:
    ///   - expression: FHIRPath expression string
    ///   - resource: Resource data as a dictionary
    /// - Returns: The result of evaluation
    public func evaluate(_ expression: String, resource: [String: Any]) -> FHIRPathValue {
        let tokens = tokenizer.tokenize(expression)
        var parser = FHIRPathParser(tokens: tokens)
        return parser.evaluate(context: resource)
    }

    /// Evaluate a FHIRPath expression and return a boolean result
    /// - Parameters:
    ///   - expression: FHIRPath expression string
    ///   - resource: Resource data as a dictionary
    /// - Returns: Boolean result of evaluation
    public func evaluateBoolean(_ expression: String, resource: [String: Any]) -> Bool {
        evaluate(expression, resource: resource).isTruthy
    }
}

// MARK: - FHIRPath Parser

/// Recursive descent parser for FHIRPath expressions
struct FHIRPathParser {
    let tokens: [FHIRPathToken]
    var position: Int = 0

    init(tokens: [FHIRPathToken]) {
        self.tokens = tokens
    }

    var current: FHIRPathToken {
        guard position < tokens.count else {
            return FHIRPathToken(type: .eof)
        }
        return tokens[position]
    }

    mutating func advance() {
        position += 1
    }

    mutating func expect(_ type: FHIRPathTokenType) -> Bool {
        if current.type == type {
            advance()
            return true
        }
        return false
    }

    // MARK: - Evaluation

    mutating func evaluate(context: Any?) -> FHIRPathValue {
        let result = parseExpression(context: context)
        return result
    }

    // expression = orExpression
    mutating func parseExpression(context: Any?) -> FHIRPathValue {
        return parseImplies(context: context)
    }

    // implies = orExpression ('implies' orExpression)*
    mutating func parseImplies(context: Any?) -> FHIRPathValue {
        var left = parseOr(context: context)
        while case .implies = current.type {
            advance()
            let right = parseOr(context: context)
            // A implies B  ≡  (not A) or B
            left = .boolean(!left.isTruthy || right.isTruthy)
        }
        return left
    }

    // orExpression = xorExpression ('or' xorExpression | 'xor' xorExpression)*
    mutating func parseOr(context: Any?) -> FHIRPathValue {
        var left = parseAnd(context: context)
        while true {
            if case .or = current.type {
                advance()
                let right = parseAnd(context: context)
                left = .boolean(left.isTruthy || right.isTruthy)
            } else if case .xor = current.type {
                advance()
                let right = parseAnd(context: context)
                left = .boolean(left.isTruthy != right.isTruthy)
            } else {
                break
            }
        }
        return left
    }

    // andExpression = comparisonExpression ('and' comparisonExpression)*
    mutating func parseAnd(context: Any?) -> FHIRPathValue {
        var left = parseComparison(context: context)
        while case .and = current.type {
            advance()
            let right = parseComparison(context: context)
            left = .boolean(left.isTruthy && right.isTruthy)
        }
        return left
    }

    // comparison = unionExpression (('=' | '!=' | '>' | '<' | '>=' | '<=') unionExpression)?
    mutating func parseComparison(context: Any?) -> FHIRPathValue {
        let left = parseUnion(context: context)

        switch current.type {
        case .equals:
            advance()
            let right = parseUnion(context: context)
            return .boolean(left == right)
        case .notEquals:
            advance()
            let right = parseUnion(context: context)
            return .boolean(left != right)
        case .greaterThan:
            advance()
            let right = parseUnion(context: context)
            return compareValues(left, right, op: >)
        case .lessThan:
            advance()
            let right = parseUnion(context: context)
            return compareValues(left, right, op: <)
        case .greaterThanOrEqual:
            advance()
            let right = parseUnion(context: context)
            return compareValues(left, right, op: >=)
        case .lessThanOrEqual:
            advance()
            let right = parseUnion(context: context)
            return compareValues(left, right, op: <=)
        default:
            return left
        }
    }

    // unionExpression = addition ('|' addition)*
    mutating func parseUnion(context: Any?) -> FHIRPathValue {
        var left = parseAddition(context: context)
        while case .pipe = current.type {
            advance()
            let right = parseAddition(context: context)
            left = unionValues(left, right)
        }
        return left
    }

    // addition = invocation ('+' invocation)*
    mutating func parseAddition(context: Any?) -> FHIRPathValue {
        var left = parseInvocation(context: context)
        while case .plus = current.type {
            advance()
            let right = parseInvocation(context: context)
            left = addValues(left, right)
        }
        return left
    }

    // invocation = primary ('.' functionOrPath)*
    mutating func parseInvocation(context: Any?) -> FHIRPathValue {
        var result = parsePrimary(context: context)

        while case .dot = current.type {
            advance()
            result = parseFunctionOrPath(context: result)
        }

        return result
    }

    // functionOrPath = identifier ('(' args? ')')?  | function
    mutating func parseFunctionOrPath(context: FHIRPathValue) -> FHIRPathValue {
        switch current.type {
        case .exists:
            advance()
            if case .openParen = current.type {
                advance()
                _ = expect(.closeParen)
            }
            return .boolean(context.isTruthy)

        case .empty:
            advance()
            if case .openParen = current.type {
                advance()
                _ = expect(.closeParen)
            }
            return .boolean(!context.isTruthy)

        case .count:
            advance()
            if case .openParen = current.type {
                advance()
                _ = expect(.closeParen)
            }
            if case .collection(let vals) = context {
                return .integer(vals.count)
            }
            return context == .empty ? .integer(0) : .integer(1)

        case .hasValue:
            advance()
            if case .openParen = current.type {
                advance()
                _ = expect(.closeParen)
            }
            return .boolean(context != .empty)

        case .not:
            advance()
            if case .openParen = current.type {
                advance()
                _ = expect(.closeParen)
            }
            return .boolean(!context.isTruthy)

        case .length:
            advance()
            if case .openParen = current.type {
                advance()
                _ = expect(.closeParen)
            }
            if let str = context.stringValue {
                return .integer(str.count)
            }
            return .empty

        case .startsWith:
            advance()
            _ = expect(.openParen)
            let arg = parseExpression(context: nil)
            _ = expect(.closeParen)
            if let str = context.stringValue, let prefix = arg.stringValue {
                return .boolean(str.hasPrefix(prefix))
            }
            return .empty

        case .endsWith:
            advance()
            _ = expect(.openParen)
            let arg = parseExpression(context: nil)
            _ = expect(.closeParen)
            if let str = context.stringValue, let suffix = arg.stringValue {
                return .boolean(str.hasSuffix(suffix))
            }
            return .empty

        case .contains:
            advance()
            _ = expect(.openParen)
            let arg = parseExpression(context: nil)
            _ = expect(.closeParen)
            if let str = context.stringValue, let sub = arg.stringValue {
                return .boolean(str.contains(sub))
            }
            return .empty

        case .where:
            advance()
            _ = expect(.openParen)
            let filterExprPosition = savePosition()
            _ = expect(.closeParen)
            return filterCollection(context, position: filterExprPosition)

        case .all:
            advance()
            _ = expect(.openParen)
            skipToCloseParen()
            // Simplified: returns true if collection is not empty
            return .boolean(context.isTruthy)

        case .identifier(let name):
            advance()
            return navigatePath(context, property: name)

        default:
            return context
        }
    }

    // primary = literal | identifier | '(' expression ')'
    mutating func parsePrimary(context: Any?) -> FHIRPathValue {
        switch current.type {
        case .stringLiteral(let val):
            advance()
            return .string(val)

        case .numberLiteral(let val):
            advance()
            if let intVal = Int(val) {
                return .integer(intVal)
            }
            if let dblVal = Double(val) {
                return .decimal(dblVal)
            }
            return .string(val)

        case .booleanLiteral(let val):
            advance()
            return .boolean(val)

        case .openParen:
            advance()
            let result = parseExpression(context: context)
            _ = expect(.closeParen)
            return result

        case .not:
            advance()
            if case .openParen = current.type {
                advance()
                let expr = parseExpression(context: context)
                _ = expect(.closeParen)
                return .boolean(!expr.isTruthy)
            }
            let expr = parsePrimary(context: context)
            return .boolean(!expr.isTruthy)

        case .exists:
            advance()
            if case .openParen = current.type {
                advance()
                _ = expect(.closeParen)
            }
            return .boolean(context != nil)

        case .identifier(let name):
            advance()
            return resolveIdentifier(name, context: context)

        default:
            advance()
            return .empty
        }
    }

    // MARK: - Helpers

    func resolveIdentifier(_ name: String, context: Any?) -> FHIRPathValue {
        guard let dict = context as? [String: Any] else { return .empty }
        return anyToValue(dict[name])
    }

    func navigatePath(_ context: FHIRPathValue, property: String) -> FHIRPathValue {
        switch context {
        case .collection(let values):
            var results: [FHIRPathValue] = []
            for val in values {
                let nav = navigatePath(val, property: property)
                if case .collection(let inner) = nav {
                    results.append(contentsOf: inner)
                } else if nav != .empty {
                    results.append(nav)
                }
            }
            return results.isEmpty ? .empty : .collection(results)
        default:
            return .empty
        }
    }

    func anyToValue(_ value: Any?) -> FHIRPathValue {
        guard let value else { return .empty }

        if let str = value as? String { return .string(str) }
        if let num = value as? Int { return .integer(num) }
        if let num = value as? Double { return .decimal(num) }
        if let bool = value as? Bool { return .boolean(bool) }
        if let arr = value as? [Any] {
            let vals = arr.map { anyToValue($0) }
            return .collection(vals)
        }
        if let dict = value as? [String: Any] {
            // Wrap dict as a single-element collection for path navigation
            return .collection([wrapDict(dict)])
        }
        return .string(String(describing: value))
    }

    /// Wrap a dictionary for path navigation.
    /// Note: This is a simplified implementation that converts to string representation.
    /// Full FHIRPath would require preserving dictionary structure for nested navigation.
    func wrapDict(_ dict: [String: Any]) -> FHIRPathValue {
        return .string(String(describing: dict))
    }

    func compareValues(_ left: FHIRPathValue, _ right: FHIRPathValue, op: (Double, Double) -> Bool) -> FHIRPathValue {
        if let lInt = left.intValue, let rInt = right.intValue {
            return .boolean(op(Double(lInt), Double(rInt)))
        }
        if let lStr = left.stringValue, let rStr = right.stringValue,
           let lDbl = Double(lStr), let rDbl = Double(rStr) {
            return .boolean(op(lDbl, rDbl))
        }
        return .empty
    }

    func unionValues(_ left: FHIRPathValue, _ right: FHIRPathValue) -> FHIRPathValue {
        var result: [FHIRPathValue] = []
        if case .collection(let vals) = left {
            result.append(contentsOf: vals)
        } else if left != .empty {
            result.append(left)
        }
        if case .collection(let vals) = right {
            result.append(contentsOf: vals)
        } else if right != .empty {
            result.append(right)
        }
        return result.isEmpty ? .empty : .collection(result)
    }

    func addValues(_ left: FHIRPathValue, _ right: FHIRPathValue) -> FHIRPathValue {
        if let lInt = left.intValue, let rInt = right.intValue {
            return .integer(lInt + rInt)
        }
        if let lStr = left.stringValue, let rStr = right.stringValue {
            return .string(lStr + rStr)
        }
        return .empty
    }

    mutating func savePosition() -> Int {
        let pos = position
        skipToCloseParen()
        return pos
    }

    /// Simplified collection filter. Full `.where()` expression evaluation
    /// is not yet implemented; returns the context as-is if truthy.
    func filterCollection(_ context: FHIRPathValue, position: Int) -> FHIRPathValue {
        return context.isTruthy ? context : .empty
    }

    mutating func skipToCloseParen() {
        var depth = 1
        while position < tokens.count && depth > 0 {
            if case .openParen = tokens[position].type { depth += 1 }
            if case .closeParen = tokens[position].type { depth -= 1 }
            if depth > 0 { advance() }
        }
        if case .closeParen = current.type { advance() }
    }
}
