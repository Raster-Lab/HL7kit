---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

A clear and concise description of what the bug is.

## To Reproduce

Steps to reproduce the behavior:

1. Create a message with '...'
2. Parse using '...'
3. Access field '...'
4. See error

## Expected Behavior

A clear and concise description of what you expected to happen.

## Actual Behavior

What actually happened instead.

## Code Sample

```swift
// Minimal code to reproduce the issue
let parser = HL7v2Parser()
let message = try parser.parse("MSH|...")
// ...
```

## Error Messages

```
Paste any error messages, stack traces, or logs here
```

## Environment

- **HL7kit Version**: [e.g., 1.0.0]
- **Swift Version**: [e.g., 6.2]
- **Platform**: [e.g., macOS 14.0, iOS 17.0]
- **Xcode Version**: [e.g., 16.0] (if applicable)

## HL7 Message Details

If relevant to parsing/validation:

- **HL7 Version**: [e.g., 2.5.1]
- **Message Type**: [e.g., ADT^A01]
- **Character Encoding**: [e.g., UTF-8]

**Message Sample** (remove all PHI):
```
MSH|^~\&|...
```

## Additional Context

Add any other context about the problem here, such as:

- Does this happen consistently or intermittently?
- Is this a regression (worked in previous version)?
- Are there workarounds you've found?
- Impact on your use case (critical, high, medium, low)

## Checklist

- [ ] I have searched existing issues to avoid duplicates
- [ ] I have removed all PHI/sensitive data from code samples
- [ ] I have tested with the latest version of HL7kit
- [ ] I have included a minimal, reproducible example
