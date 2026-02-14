# Contributing to HL7kit

Thank you for your interest in contributing to HL7kit! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)
- [Review Process](#review-process)
- [Community](#community)

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

## Getting Started

### Prerequisites

- **Swift 6.0+** (Swift 6.2 recommended)
- **Xcode 16.0+** or **Swift toolchain** for your platform
- **Git** for version control
- Familiarity with Swift Package Manager
- Understanding of HL7 standards (helpful but not required)

### Setting Up Your Development Environment

1. **Fork the repository** on GitHub

2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR-USERNAME/HL7kit.git
   cd HL7kit
   ```

3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/Raster-Lab/HL7kit.git
   ```

4. **Build the project**:
   ```bash
   swift build
   ```

5. **Run tests**:
   ```bash
   swift test
   ```

6. **Generate documentation** (optional):
   ```bash
   swift package generate-documentation
   ```

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

- **Bug Fixes**: Fix issues reported in GitHub Issues
- **New Features**: Implement new HL7 message types, validation rules, or functionality
- **Performance Improvements**: Optimize parsing, memory usage, or throughput
- **Documentation**: Improve guides, API docs, or examples
- **Tests**: Add test coverage or improve existing tests
- **Examples**: Create new examples demonstrating HL7kit usage
- **Security**: Identify and fix security vulnerabilities

### Finding Work

- Browse [GitHub Issues](https://github.com/Raster-Lab/HL7kit/issues) for open tasks
- Look for issues labeled `good first issue` for beginner-friendly tasks
- Check issues labeled `help wanted` for tasks needing contributors
- Review [milestone.md](milestone.md) for roadmap items
- Propose new features via GitHub Discussions

### Before You Start

1. **Check existing issues** to avoid duplicate work
2. **Comment on the issue** you want to work on to claim it
3. **Discuss major changes** in a GitHub Discussion or Issue first
4. **Read relevant documentation** (ARCHITECTURE.md, CODING_STANDARDS.md, etc.)

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 2. Make Your Changes

- Follow [CODING_STANDARDS.md](CODING_STANDARDS.md)
- Write clean, readable, documented code
- Add or update tests
- Update documentation if needed

### 3. Test Your Changes

```bash
# Run all tests
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Run specific test
swift test --filter TestClassName.testMethodName

# Run benchmarks
swift test --filter BenchmarkTests
```

### 4. Lint Your Code

```bash
# If SwiftLint is configured
swiftlint
```

### 5. Commit Your Changes

Write clear, descriptive commit messages:

```bash
git commit -m "[Module] Brief description of change

Detailed explanation of what changed and why.
Reference any related issues: Fixes #123"
```

Examples:
- `[HL7v2Kit] Add support for OML^O21 message type`
- `[HL7Core] Fix memory leak in object pool`
- `[Tests] Add coverage for FHIR Bundle validation`
- `[Docs] Update Quick Start guide with FHIR examples`

### 6. Keep Your Branch Updated

```bash
git fetch upstream
git rebase upstream/main
```

### 7. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

## Coding Standards

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use Swift 6.2 features (async/await, actors, Sendable)
- Enable strict concurrency checking
- See [CODING_STANDARDS.md](CODING_STANDARDS.md) for detailed guidelines

### Code Quality

- **No compiler warnings** - All warnings must be resolved
- **Type safety** - Leverage Swift's type system
- **Error handling** - Use proper Swift error handling (throw/try/catch)
- **Thread safety** - Use actors for mutable state
- **Memory efficiency** - Optimize for low memory footprint
- **Performance** - Consider algorithmic complexity

### Documentation

All public APIs must have documentation:

```swift
/// Parses an HL7 v2.x message from a string.
///
/// This parser supports HL7 versions 2.1 through 2.8 and uses a streaming
/// approach for memory efficiency.
///
/// - Parameter input: The HL7 message string to parse
/// - Returns: A parsed `HL7v2Message` object
/// - Throws: `HL7v2ParseError` if the message is invalid
///
/// ## Example
///
/// ```swift
/// let parser = HL7v2Parser()
/// let message = try parser.parse(hl7String)
/// ```
public func parse(_ input: String) throws -> HL7v2Message {
    // Implementation
}
```

## Testing Requirements

### Code Coverage

- **Minimum 90% code coverage** for all new code
- Aim for comprehensive test coverage including:
  - Happy path scenarios
  - Edge cases and error conditions
  - Performance characteristics
  - Thread safety

### Test Structure

```swift
import XCTest
@testable import HL7v2Kit

final class MyFeatureTests: XCTestCase {
    
    // MARK: - Happy Path Tests
    
    func testBasicParsing() {
        // Given
        let input = "MSH|^~\\&|..."
        
        // When
        let result = try parser.parse(input)
        
        // Then
        XCTAssertEqual(result.messageType, "ADT^A01")
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyInput() {
        XCTAssertThrowsError(try parser.parse(""))
    }
    
    // MARK: - Performance Tests
    
    func testParsingPerformance() {
        measure {
            _ = try? parser.parse(largeMessage)
        }
    }
}
```

### Running Tests

```bash
# All tests
swift test

# Specific test suite
swift test --filter HL7v2KitTests

# With coverage
swift test --enable-code-coverage

# Generate coverage report
xcrun llvm-cov report .build/debug/HL7kitPackageTests.xctest/Contents/MacOS/HL7kitPackageTests -instr-profile .build/debug/codecov/default.profdata
```

## Documentation

### Types of Documentation

1. **API Documentation** (DocC comments in code)
2. **Guides** (Markdown files like INTEGRATION_GUIDE.md)
3. **Examples** (Swift files in Examples/ directory)
4. **README.md** updates

### Writing Good Documentation

- Be clear and concise
- Include code examples
- Explain the "why", not just the "what"
- Update docs when changing behavior
- Check for broken links
- Use proper Markdown formatting

## Submitting Changes

### Pull Request Process

1. **Ensure all tests pass** locally
2. **Update documentation** if needed
3. **Add entry to CHANGELOG.md** under "Unreleased" section
4. **Push to your fork**
5. **Create Pull Request** on GitHub

### Pull Request Template

```markdown
## Description
Brief description of the changes

## Related Issues
Fixes #123
Related to #456

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Performance improvement
- [ ] Documentation update
- [ ] Breaking change

## Checklist
- [ ] All tests pass locally
- [ ] Added/updated tests (if applicable)
- [ ] Added/updated documentation (if applicable)
- [ ] Code follows project style guidelines
- [ ] No compiler warnings
- [ ] CHANGELOG.md updated
- [ ] Code coverage ≥ 90%

## Testing
Describe the testing you performed

## Screenshots (if applicable)
Add screenshots for UI changes
```

### Pull Request Guidelines

- **One feature per PR** - Keep PRs focused and reviewable
- **Descriptive title** - Summarize the change clearly
- **Reference issues** - Link to related issues
- **Small PRs** - Easier to review and merge
- **Clear description** - Explain what and why
- **Tests included** - All changes must have tests

## Review Process

### What to Expect

1. **Automated Checks**: CI/CD will run tests, coverage, and linting
2. **Code Review**: Maintainers will review your code
3. **Feedback**: You may receive requests for changes
4. **Iteration**: Update your PR based on feedback
5. **Approval**: Once approved, your PR will be merged

### Review Criteria

- Code quality and style
- Test coverage
- Documentation completeness
- Performance impact
- Security considerations
- Backward compatibility
- Standards compliance

### Responding to Feedback

- Be responsive to review comments
- Ask questions if feedback is unclear
- Make requested changes promptly
- Update your branch if conflicts arise
- Be respectful and professional

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Pull Requests**: Code contributions and reviews
- **Security Issues**: security@hl7kit.org (private)

### Getting Help

- Read the [documentation](README.md)
- Check [existing issues](https://github.com/Raster-Lab/HL7kit/issues)
- Ask in [GitHub Discussions](https://github.com/Raster-Lab/HL7kit/discussions)
- Review [examples](Examples/)

### Recognition

Contributors are recognized in:
- Git commit history
- CHANGELOG.md
- GitHub contributors page
- Release notes

## Security

If you discover a security vulnerability:

1. **Do NOT** open a public issue
2. **Email** security@hl7kit.org with details
3. **Wait** for response before public disclosure
4. See [SECURITY_GUIDE.md](SECURITY_GUIDE.md) for more info

## License

By contributing to HL7kit, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have questions about contributing:

1. Check this guide thoroughly
2. Review existing documentation
3. Search closed issues and PRs
4. Ask in GitHub Discussions
5. Reach out to maintainers

---

Thank you for contributing to HL7kit! Your contributions help make healthcare interoperability better for everyone. 🏥💙

