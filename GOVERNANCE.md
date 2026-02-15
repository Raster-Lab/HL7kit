# HL7kit Project Governance

This document outlines the governance model for the HL7kit project, including decision-making processes, roles and responsibilities, and community participation guidelines.

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Roles and Responsibilities](#roles-and-responsibilities)
- [Decision Making](#decision-making)
- [Contribution Process](#contribution-process)
- [Release Authority](#release-authority)
- [Conflict Resolution](#conflict-resolution)
- [Code of Conduct Enforcement](#code-of-conduct-enforcement)
- [Governance Changes](#governance-changes)

## Overview

HL7kit is an open-source Swift framework for healthcare interoperability, supporting HL7 v2.x, v3.x, and FHIR standards. The project is committed to:

- **Transparency**: All decisions are documented and accessible
- **Meritocracy**: Contributions are valued based on technical merit and alignment with project goals
- **Community**: Welcoming diverse perspectives and fostering collaboration
- **Healthcare Excellence**: Maintaining the highest standards for healthcare data handling
- **Security First**: Prioritizing security and compliance in all decisions

## Project Structure

### Organization

- **Repository Owner**: Raster-Lab organization
- **Primary Repository**: https://github.com/Raster-Lab/HL7kit
- **License**: MIT License
- **Project Type**: Open-source library for Apple platforms

### Communication Channels

- **GitHub Issues**: Bug reports, feature requests, and task tracking
- **GitHub Discussions**: Questions, ideas, and community conversations
- **Pull Requests**: Code reviews and contribution discussions
- **Security Email**: security@hl7kit.org (private security vulnerability reports)

## Roles and Responsibilities

### Project Lead

**Responsibilities:**
- Set project vision and strategic direction
- Make final decisions on controversial or critical issues
- Approve maintainer nominations
- Represent the project in external communications
- Ensure project alignment with healthcare standards

**Current Project Lead:** Appointed by Raster-Lab organization

### Core Maintainers

**Qualifications:**
- Significant contributions to the codebase (100+ commits or equivalent impact)
- Deep understanding of HL7 standards and Swift programming
- Demonstrated commitment to project quality and community
- Active participation for at least 6 months

**Responsibilities:**
- Review and merge pull requests
- Guide technical architecture decisions
- Mentor contributors
- Maintain code quality and test coverage (≥90%)
- Ensure security best practices
- Triage issues and set priorities
- Participate in release planning

**Rights:**
- Write access to the repository
- Vote on maintainer decisions (when applicable)
- Propose changes to governance
- Participate in release approval

**Current Core Maintainers:** Listed in MAINTAINERS.md (to be created upon promotion of first community maintainer)

### Contributors

**Qualifications:**
- Anyone who submits a pull request or participates in the community

**Responsibilities:**
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md)
- Adhere to [Coding Standards](CODING_STANDARDS.md)
- Meet [Contribution Guidelines](CONTRIBUTING.md)
- Respect maintainer decisions

**Rights:**
- Submit issues and pull requests
- Participate in discussions
- Request features or improvements
- Receive credit for accepted contributions

### Security Team

**Responsibilities:**
- Review and respond to security vulnerability reports
- Coordinate security patches and advisories
- Maintain SECURITY_GUIDE.md
- Ensure HIPAA compliance guidelines are met

**Composition:** Project Lead + designated Core Maintainers with security expertise

## Decision Making

### Consensus-Based Approach

HL7kit follows a **consensus-seeking** decision-making model:

1. **Proposal**: Any community member can propose changes via issues or discussions
2. **Discussion**: Open discussion period (minimum 7 days for major changes)
3. **Consensus**: Core Maintainers seek agreement
4. **Resolution**: Decision is made and documented

### Decision Types

#### 1. Technical Decisions

**Examples:** API design, architectural changes, dependencies, performance optimizations

**Process:**
- Open discussion in GitHub Issues or Pull Requests
- Core Maintainers review and provide feedback
- Consensus is preferred; if no consensus, Project Lead decides
- Decision is documented in the PR or issue

**Approval Requirements:**
- Minor changes: 1 Core Maintainer approval
- Major changes: 2 Core Maintainer approvals or Project Lead approval
- Breaking changes: Project Lead approval required

#### 2. Community Decisions

**Examples:** Governance changes, Code of Conduct updates, process changes

**Process:**
- Open discussion period (minimum 14 days)
- Community feedback is solicited
- Core Maintainers vote if needed
- Project Lead has veto power

**Approval Requirements:**
- Majority approval from Core Maintainers
- No objections from Project Lead

#### 3. Security Decisions

**Examples:** Security patches, vulnerability disclosures, security policy changes

**Process:**
- Private discussion in security channel
- Expedited review (within 48 hours for critical issues)
- Security Team makes decision
- Public disclosure follows responsible disclosure timeline

**Approval Requirements:**
- Security Team consensus
- Project Lead notification required

#### 4. Release Decisions

**Process:** See [Release Authority](#release-authority) section

### Voting (When Required)

When consensus cannot be reached:

- **Eligible Voters**: Core Maintainers
- **Voting Period**: 7 days minimum
- **Quorum**: 50% of Core Maintainers must participate
- **Approval**: Simple majority (>50%)
- **Tie-Breaker**: Project Lead decides

## Contribution Process

### Contribution Acceptance Criteria

All contributions must meet the following standards:

#### Code Quality
- ✅ Follows [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- ✅ Adheres to project [Coding Standards](CODING_STANDARDS.md)
- ✅ Passes SwiftLint checks (zero errors, minimal warnings)
- ✅ Maintains ≥90% code coverage
- ✅ Includes comprehensive unit tests
- ✅ Passes all existing tests

#### Documentation
- ✅ Public APIs have DocC-compatible documentation
- ✅ Complex logic includes inline comments
- ✅ README.md updated if public API changes
- ✅ CHANGELOG.md updated for notable changes
- ✅ Migration guide updated for breaking changes

#### Standards Compliance
- ✅ Follows HL7/FHIR specifications
- ✅ Maintains standards compliance (see COMPLIANCE_STATUS.md)
- ✅ Handles healthcare data securely
- ✅ Respects PHI protection requirements

#### Security
- ✅ No security vulnerabilities introduced
- ✅ Input validation implemented
- ✅ Sensitive data handling reviewed
- ✅ Security scan passes (CodeQL or equivalent)

#### Performance
- ✅ No significant performance regressions
- ✅ Memory usage is reasonable
- ✅ Benchmark tests pass (if applicable)

### Review Process

1. **Automated Checks**: CI/CD pipeline runs automatically
   - Build verification
   - Test execution and coverage
   - Linting and formatting
   - Security scanning

2. **Code Review**: Core Maintainers review code
   - Technical correctness
   - Code quality and style
   - Test coverage and quality
   - Documentation completeness
   - Security considerations

3. **Feedback Loop**: Author addresses feedback
   - Respond to all review comments
   - Make requested changes
   - Re-request review

4. **Approval**: Maintainer(s) approve
   - Minor changes: 1 approval required
   - Major changes: 2 approvals required
   - Breaking changes: Project Lead approval required

5. **Merge**: Contribution is merged
   - Squash merge for cleaner history (typical)
   - Merge commit for preserving history (when appropriate)
   - Rebase for linear history (rare)

### Contribution SLA

- **Initial Response**: Within 3 business days
- **Review Completion**: Within 7 business days (simple changes) or 14 days (complex changes)
- **Security Issues**: Within 48 hours (critical) or 7 days (non-critical)

## Release Authority

### Release Types

Following [Semantic Versioning 2.0.0](https://semver.org/):

- **Major (X.0.0)**: Breaking changes, major features, removed APIs
- **Minor (x.Y.0)**: New features, non-breaking changes
- **Patch (x.y.Z)**: Bug fixes, security patches, performance improvements

### Release Authority Matrix

| Release Type | Who Can Approve | Approval Required |
|--------------|-----------------|-------------------|
| Patch Release | Any Core Maintainer | 1 Core Maintainer |
| Minor Release | Core Maintainers | 2 Core Maintainers |
| Major Release | Project Lead | Project Lead + 2 Core Maintainers |
| Security Patch | Security Team | Security Team consensus |
| Hotfix (Critical) | Project Lead | Project Lead (expedited) |

### Release Process

See [RELEASE_CADENCE.md](RELEASE_CADENCE.md) for detailed release schedule and procedures.

**Quick Overview:**
1. Release candidate is created from main branch
2. Testing period (varies by release type)
3. Approval from authorized individuals
4. Release is published to GitHub
5. CHANGELOG.md is updated
6. Community is notified

## Conflict Resolution

### Conflict Types

#### 1. Technical Disagreements

**Process:**
1. Participants state their positions clearly
2. Open discussion for alternative solutions
3. Core Maintainers mediate if needed
4. If no consensus: Vote or Project Lead decides
5. Decision is documented and final

#### 2. Code Review Disputes

**Process:**
1. Contributor addresses feedback in good faith
2. If disagreement persists: Request additional reviewer
3. Third reviewer or Project Lead makes final call
4. Contributor can appeal to Project Lead

#### 3. Community Conduct Issues

**Process:**
1. Report to security@hl7kit.org or Project Lead
2. Confidential investigation
3. Decision by Project Lead with input from Core Maintainers
4. Actions taken per [Code of Conduct](CODE_OF_CONDUCT.md)

#### 4. Governance Disputes

**Process:**
1. Raise concern in GitHub Discussions
2. Community feedback period (14 days)
3. Core Maintainers discuss and propose resolution
4. Project Lead makes final decision
5. Governance document updated if needed

### Escalation Path

1. **Level 1**: Discuss with involved parties
2. **Level 2**: Request Core Maintainer mediation
3. **Level 3**: Escalate to Project Lead
4. **Level 4**: Project Lead decision is final

### Principles

- **Good Faith**: Assume positive intent
- **Respect**: Maintain professional discourse
- **Transparency**: Document decisions and rationale
- **Finality**: Accept decisions and move forward
- **Learning**: Use conflicts as learning opportunities

## Code of Conduct Enforcement

### Reporting

Report violations to:
- **Email**: security@hl7kit.org
- **Private GitHub message** to Project Lead

### Investigation

1. Report received and acknowledged (within 24 hours)
2. Confidential investigation by Project Lead
3. Evidence gathered from all parties
4. Decision made within 7 days (urgent) or 14 days (non-urgent)

### Consequences

Progressive enforcement based on severity:

1. **Warning**: Private written warning
2. **Temporary Ban**: Time-limited removal from project participation
3. **Permanent Ban**: Permanent removal from project
4. **Immediate Ban**: For severe violations (harassment, threats, etc.)

### Appeals

- Appeals can be submitted to Project Lead within 14 days
- Decision is reviewed by uninvolved Core Maintainer(s)
- Appeal decision is final

## Governance Changes

### Process for Modifying Governance

1. **Proposal**: Submit via GitHub Issue or Discussion
2. **Discussion**: Minimum 14-day open discussion period
3. **Draft**: Core Maintainers draft updated governance document
4. **Feedback**: Second community feedback period (7 days)
5. **Vote**: Core Maintainers vote (majority approval required)
6. **Approval**: Project Lead approves final version
7. **Publication**: Updated GOVERNANCE.md is committed

### Amendment History

- **v1.0.0** (2026-02-15): Initial governance document created

### Regular Review

- Governance is reviewed annually
- Community feedback is solicited
- Updates are made as project evolves

## Becoming a Core Maintainer

### Nomination Process

1. **Nomination**: Any Core Maintainer can nominate a contributor
2. **Criteria Review**: Verify nominee meets qualifications
3. **Discussion**: Private discussion among Core Maintainers (7 days)
4. **Vote**: Core Maintainers vote (unanimous approval required for first year, majority thereafter)
5. **Approval**: Project Lead approves
6. **Invitation**: Nominee is invited and accepts
7. **Onboarding**: New maintainer is granted access and added to MAINTAINERS.md

### Stepping Down

Core Maintainers can step down at any time:
1. Notify Project Lead
2. Transfer responsibilities
3. Access is revoked
4. Contributor status remains
5. Recognition in project history

### Inactive Maintainers

- Maintainers inactive for 12+ months may be moved to emeritus status
- Emeritus maintainers are honored but have no active role
- Can return to active status upon request and approval

## Questions and Clarifications

For questions about this governance model:
- Open a GitHub Discussion
- Contact Project Lead
- Reference this document in issues

---

**Document Version**: 1.0.0  
**Last Updated**: 2026-02-15  
**Next Review**: 2027-02-15

---

*This governance model is designed to serve the HL7kit community while maintaining the high standards required for healthcare interoperability software. It will evolve as the project and community grow.*
