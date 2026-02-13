# GitHub Copilot Instructions for HL7kit

## Task Completion Guidelines

When completing any task in the HL7kit project, ensure the following requirements are met:

### 1. Documentation Updates

#### README.md
- Update the README.md file to reflect any new features, changes, or improvements
- Keep the overview section current and accurate
- Update installation instructions if package dependencies change
- Add new examples or usage patterns as appropriate
- Ensure links to documentation are valid

#### milestone.md
- Update milestone.md to mark completed tasks as done (change `[ ]` to `[x]`)
- Add any new milestones or deliverables discovered during implementation
- Update phase status and timelines if necessary
- Document any blockers or risks in the appropriate sections
- Keep the next steps section current

#### CLI Tool (`hl7`)
- When a feature is completed in any library module (HL7Core, HL7v2Kit, HL7v3Kit, FHIRkit), update the CLI tool to expose and support the new functionality
- Add new subcommands or options to the `hl7` CLI executable as appropriate
- Ensure CLI commands provide both text and JSON output formats (`--format text|json`)
- Update CLI help text in `Sources/HL7CLI/HelpText.swift` to document new commands and options
- Add corresponding CLI tests in `Tests/HL7CLITests/`
- Verify the CLI tool builds and runs correctly with `swift build` and `swift run hl7`

### 2. Code Coverage Requirements

#### Target: 90% Code Coverage
- All new code must have corresponding unit tests
- Aim for comprehensive test coverage across:
  - Happy path scenarios
  - Error handling and edge cases
  - Performance tests for critical paths
  - Integration tests where applicable

#### Testing Best Practices
- Use XCTest framework for all tests
- Follow existing test patterns in the codebase
- Create mock objects for external dependencies
- Test async/await and actor-based code properly
- Include performance tests using `measure` blocks
- Verify Sendable conformance for concurrent code

#### Coverage Verification
- Run tests with coverage: `swift test --enable-code-coverage`
- Generate coverage reports using llvm-cov
- Check CI/CD pipeline for automated coverage reports
- Address any gaps in coverage before marking tasks complete

### 3. Quality Checks

Before completing any task:
- [ ] All tests pass locally
- [ ] Code coverage is at or above 90%
- [ ] SwiftLint passes (if configured)
- [ ] Documentation is updated
- [ ] milestone.md reflects current progress
- [ ] README.md is accurate and current
- [ ] CLI tool updated to expose new features (if applicable)
- [ ] No compiler warnings
- [ ] Code follows Swift 6.2 best practices
- [ ] Sendable and concurrency safety verified

### 4. Commit Messages

Use clear, descriptive commit messages:
- Format: `[Module] Brief description of change`
- Examples:
  - `[HL7Core] Add validation framework base protocols`
  - `[HL7v2Kit] Implement MSH segment parser`
  - `[Tests] Add coverage for error handling`
  - `[Docs] Update milestone status for Phase 0`

### 5. Pull Request Guidelines

When creating PRs:
- Reference related issues or milestones
- Include a summary of changes
- Highlight any breaking changes
- List test coverage metrics
- Update documentation links if applicable

### 6. Code Quality Standards

#### Swift 6.2 Features
- Use strict concurrency checking
- Leverage actors for thread-safe operations
- Use async/await for asynchronous code
- Apply Sendable protocol where appropriate
- Use modern language features (result builders, property wrappers, etc.)

#### Performance Considerations
- Optimize for low memory footprint
- Use copy-on-write for data structures
- Implement lazy parsing where beneficial
- Profile critical paths
- Document performance characteristics

#### Security
- Never commit sensitive data
- Validate all inputs
- Use secure communication protocols
- Follow HIPAA compliance guidelines for healthcare data
- Document security considerations

### 7. Continuous Integration

The CI/CD pipeline automatically:
- Builds the package
- Runs all tests with coverage
- Generates coverage reports
- Runs SwiftLint (if configured)
- Generates documentation
- Reports coverage percentage in PR checks

Ensure all CI checks pass before merging.

### 8. Documentation Requirements

#### Code Documentation
- All public APIs must have DocC-compatible documentation
- Include code examples in documentation where helpful
- Document parameters, return values, and thrown errors
- Add `@available` attributes for version-specific features

#### API Documentation
- Use `///` for DocC comments
- Include usage examples
- Document thread safety and concurrency considerations
- Note performance characteristics where relevant

### 9. Version Control

- Keep commits atomic and focused
- Avoid committing build artifacts
- Use .gitignore to exclude unnecessary files
- Tag releases following semantic versioning
- Maintain a clean commit history

### 10. Task Completion Checklist

For every completed task:
- [x] Code implemented and working
- [x] Unit tests written and passing
- [x] Code coverage ≥ 90%
- [x] Documentation updated (inline and external)
- [x] README.md updated if needed
- [x] milestone.md updated with task status
- [x] CLI tool updated to expose new features (if applicable)
- [x] CI/CD pipeline passing
- [x] Code reviewed (if applicable)
- [x] No security vulnerabilities introduced
- [x] Performance tested if applicable

---

## Project Structure

```
HL7kit/
├── Sources/
│   ├── HL7Core/          # Shared utilities and protocols
│   ├── HL7v2Kit/         # HL7 v2.x implementation
│   ├── HL7v3Kit/         # HL7 v3.x implementation
│   ├── FHIRkit/          # FHIR implementation
│   ├── HL7CLI/           # CLI tool core logic (commands, help text)
│   └── HL7CLIEntry/      # CLI executable entry point
├── Tests/
│   ├── HL7CoreTests/
│   ├── HL7v2KitTests/
│   ├── HL7v3KitTests/
│   ├── FHIRkitTests/
│   └── HL7CLITests/
├── .github/
│   ├── workflows/        # CI/CD pipelines
│   └── copilot-instructions.md
├── Package.swift         # Swift Package Manager manifest
├── README.md            # Project overview
├── milestone.md         # Development milestones
└── .gitignore          # Git ignore rules
```

---

## Getting Started

1. Clone the repository
2. Run `swift build` to build the package
3. Run `swift test` to run all tests
4. Run `swift test --enable-code-coverage` to generate coverage

## Resources

- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [DocC Documentation](https://www.swift.org/documentation/docc/)
- [HL7 Standards](https://www.hl7.org/)
- [FHIR Specification](https://www.hl7.org/fhir/)

---

*These instructions ensure consistency and quality across all contributions to HL7kit.*