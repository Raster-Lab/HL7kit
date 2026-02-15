# HL7kit Release Cadence

This document defines the release schedule, versioning strategy, and release procedures for the HL7kit project.

## Table of Contents

- [Overview](#overview)
- [Versioning Strategy](#versioning-strategy)
- [Release Types](#release-types)
- [Release Schedule](#release-schedule)
- [Release Process](#release-process)
- [Branch Strategy](#branch-strategy)
- [Support Policy](#support-policy)
- [Deprecation Policy](#deprecation-policy)
- [Release Checklist](#release-checklist)

## Overview

HL7kit follows a predictable, time-based release schedule to provide:
- **Stability**: Regular, tested releases
- **Predictability**: Known release dates for planning
- **Quality**: Adequate testing and review time
- **Flexibility**: Security patches and critical fixes as needed

### Key Principles

- **Semantic Versioning**: We follow [SemVer 2.0.0](https://semver.org/)
- **Time-Based Releases**: Regular release cycles (not feature-based)
- **Quality First**: Testing and security take precedence over deadlines
- **Community Transparency**: Release plans are public and documented
- **Healthcare Standards**: Compliance with HL7/FHIR standards is mandatory

## Versioning Strategy

### Semantic Versioning (SemVer 2.0.0)

Format: **MAJOR.MINOR.PATCH** (e.g., 1.2.3)

#### MAJOR Version (X.0.0)

Incremented when making incompatible API changes:
- Breaking changes to public APIs
- Removal of deprecated features
- Major architectural changes
- Minimum Swift or platform version increases
- Changes requiring user code modifications

**Examples:**
- `1.0.0` → `2.0.0`: Renamed core protocols, removed deprecated methods
- `2.0.0` → `3.0.0`: Minimum iOS version increased from 16.0 to 17.0

#### MINOR Version (x.Y.0)

Incremented when adding functionality in a backward-compatible manner:
- New features and capabilities
- New APIs or protocols
- Performance improvements
- New HL7/FHIR resource support
- Enhanced validation rules
- Non-breaking changes to existing functionality

**Examples:**
- `1.0.0` → `1.1.0`: Added FHIR R5 support
- `1.1.0` → `1.2.0`: Implemented subscription notifications

#### PATCH Version (x.y.Z)

Incremented for backward-compatible bug fixes:
- Bug fixes
- Security patches
- Performance optimizations
- Documentation improvements
- Test improvements
- Internal refactoring (no API changes)

**Examples:**
- `1.2.0` → `1.2.1`: Fixed memory leak in parser
- `1.2.1` → `1.2.2`: Security patch for encryption issue

### Pre-Release Versions

For beta testing and release candidates:

- **Alpha**: `X.Y.Z-alpha.N` (internal testing, unstable)
- **Beta**: `X.Y.Z-beta.N` (external testing, feature-complete)
- **Release Candidate**: `X.Y.Z-rc.N` (ready for release pending testing)

**Examples:**
- `2.0.0-alpha.1`: First alpha of v2.0.0
- `2.0.0-beta.2`: Second beta of v2.0.0
- `2.0.0-rc.1`: Release candidate 1 for v2.0.0

### Build Metadata

Build metadata can be appended with `+`:
- `1.0.0+20260215`: Build on 2026-02-15
- `1.0.0+build.123`: Build number 123

## Release Types

### Regular Releases

#### Major Release (X.0.0)

**Frequency**: Once per year (typically Q1)  
**Planning**: 3-6 months in advance  
**Testing Period**: 6-8 weeks  
**Beta Period**: 4 weeks minimum

**Triggers:**
- Annual major version bump
- Significant architectural changes
- Breaking API changes accumulated
- New Swift language version adoption

#### Minor Release (x.Y.0)

**Frequency**: Every 2-3 months  
**Planning**: 1-2 months in advance  
**Testing Period**: 2-3 weeks  
**Beta Period**: 1-2 weeks (if needed)

**Triggers:**
- New features ready for release
- Significant enhancements
- New HL7/FHIR version support

#### Patch Release (x.y.Z)

**Frequency**: As needed (typically every 2-4 weeks)  
**Planning**: 1 week in advance  
**Testing Period**: 3-5 days  
**Beta Period**: Not required

**Triggers:**
- Bug fixes accumulated
- Security patches
- Performance improvements

### Special Releases

#### Security Release

**Timing**: Immediate (for critical) or next patch cycle (for non-critical)  
**Testing Period**: Expedited (1-2 days for critical)  
**Notification**: Security advisory published

**Process:**
- Private security fix development
- Expedited review by security team
- Coordinated disclosure
- Immediate release for critical vulnerabilities

#### Hotfix Release

**Timing**: Emergency release for critical production issues  
**Testing Period**: Minimal (1 day)  
**Approval**: Project Lead required

**Criteria:**
- Critical bug affecting production systems
- Data corruption or loss risk
- Severe performance degradation
- Security vulnerability exploitation in the wild

## Release Schedule

### Yearly Calendar (Example: 2026)

| Release Type | Target Date | Version | Features/Goals |
|--------------|-------------|---------|----------------|
| Major | Q1 (January-March) | 2.0.0 | Annual major release with breaking changes |
| Minor | Q2 (April-June) | 2.1.0 | New features and enhancements |
| Patch | Monthly | 2.1.x | Bug fixes and security patches |
| Minor | Q3 (July-September) | 2.2.0 | New features and enhancements |
| Patch | Monthly | 2.2.x | Bug fixes and security patches |
| Minor | Q4 (October-December) | 2.3.0 | New features and enhancements |
| Patch | Monthly | 2.3.x | Bug fixes and security patches |

### Proposed Schedule for 2026

#### Q1 2026: Foundation Stability
- **January**: Patch releases (1.0.x)
- **February**: Minor release (1.1.0) - Enhanced validation, performance improvements
- **March**: Patch releases (1.1.x)

#### Q2 2026: Feature Expansion
- **April**: Minor release (1.2.0) - New FHIR resources, extended HL7 v3 support
- **May**: Patch releases (1.2.x)
- **June**: Minor release (1.3.0) - Platform integrations, developer tools

#### Q3 2026: Enterprise Features
- **July**: Patch releases (1.3.x)
- **August**: Minor release (1.4.0) - Advanced security, audit features
- **September**: Patch releases (1.4.x)

#### Q4 2026: Major Version Planning
- **October**: Minor release (1.5.0) - Final features for v1.x
- **November**: Patch releases (1.5.x), 2.0.0 alpha releases
- **December**: 2.0.0 beta releases

#### Q1 2027: Major Release
- **January**: 2.0.0 release candidate
- **February**: 2.0.0 final release
- **March**: 2.0.x patch releases

### Release Windows

To avoid conflicts with holidays and Apple's ecosystem:

**Preferred Release Windows:**
- **Mid-January to mid-March**: Post-holiday, pre-WWDC
- **Mid-April to mid-June**: Post-WWDC, summer planning
- **Mid-July to mid-September**: Pre-Apple fall events
- **Mid-October to mid-November**: Post-Apple fall events, pre-holidays

**Avoid Releasing:**
- Late December / Early January (holidays)
- June (WWDC week)
- September (Apple fall event weeks)
- Major holiday weeks

## Release Process

### Phase 1: Planning

**Timeline**: 2-12 weeks before release (varies by type)

1. **Feature Freeze Date**: Set date for code freeze
2. **Release Goals**: Define objectives and scope
3. **Issue Triage**: Review and prioritize issues
4. **Milestone Creation**: Create GitHub milestone
5. **Communication**: Announce release plan

**Deliverables:**
- Release milestone in GitHub
- Feature list or changelog draft
- Testing plan

### Phase 2: Development

**Timeline**: Varies by release type

1. **Feature Development**: Implement planned features
2. **Code Review**: Maintain quality standards
3. **Testing**: Continuous testing during development
4. **Documentation**: Update as features are added

**Requirements:**
- All code reviewed and approved
- Tests pass with ≥90% coverage
- Documentation updated
- No high-severity bugs

### Phase 3: Code Freeze

**Timeline**: 1-6 weeks before release (varies by type)

**Actions:**
1. **Announce Code Freeze**: No new features
2. **Create Release Branch**: `release/vX.Y.Z`
3. **Focus on Stabilization**: Bug fixes only
4. **Comprehensive Testing**: Full test suite
5. **Security Scan**: Run security audits
6. **Performance Testing**: Benchmark tests
7. **Documentation Review**: Final doc updates

**Allowed During Code Freeze:**
- Bug fixes (merged to both main and release branch)
- Test improvements
- Documentation updates
- Critical security patches

**Not Allowed:**
- New features
- Refactoring
- Non-critical changes

### Phase 4: Pre-Release Testing

**Timeline**: 1-4 weeks before release (varies by type)

**Actions:**
1. **Create Pre-Release**: Tag alpha/beta/RC version
2. **Internal Testing**: Core maintainers test
3. **Beta Testing**: Community testing (for major/minor releases)
4. **Collect Feedback**: Gather and triage issues
5. **Address Blockers**: Fix critical bugs
6. **Regression Testing**: Ensure fixes don't break other features

**Pre-Release Tags:**
- Alpha: Internal testing, feature-complete
- Beta: External testing, stable
- RC: Release candidate, final testing

### Phase 5: Release

**Timeline**: Release day

**Actions:**
1. **Final Checks**: Run full test suite
2. **Create Release Tag**: `vX.Y.Z`
3. **Build Artifacts**: If applicable
4. **Update CHANGELOG.md**: Complete changelog
5. **Update README.md**: Version info, badges
6. **Update MIGRATION_GUIDE.md**: For breaking changes
7. **GitHub Release**: Create release with notes
8. **Documentation**: Publish updated docs
9. **Announcement**: Notify community

**Release Checklist:** See [Release Checklist](#release-checklist) section

### Phase 6: Post-Release

**Timeline**: 1-2 weeks after release

**Actions:**
1. **Monitor Issues**: Watch for bug reports
2. **Hot Fixes**: Address critical issues
3. **Retrospective**: Review release process
4. **Next Release Planning**: Begin planning next cycle

## Branch Strategy

### Main Branches

#### `main`
- **Purpose**: Current stable release
- **Protection**: Protected, requires reviews
- **Merge From**: Release branches, hotfix branches
- **Status**: Always deployable

#### `develop` (optional for larger teams)
- **Purpose**: Integration branch for next release
- **Protection**: Protected, requires reviews
- **Merge From**: Feature branches
- **Merge To**: Release branches

### Supporting Branches

#### Feature Branches: `feature/description`
- **Purpose**: Individual feature development
- **Created From**: `main` or `develop`
- **Merge To**: `main` or `develop`
- **Lifetime**: Until feature is complete
- **Example**: `feature/add-fhir-r5-support`

#### Release Branches: `release/vX.Y.Z`
- **Purpose**: Prepare for release
- **Created From**: `main` or `develop`
- **Merge To**: `main` and back-merge to `develop`
- **Lifetime**: Until release is published
- **Example**: `release/v2.0.0`

#### Hotfix Branches: `hotfix/description`
- **Purpose**: Emergency fixes for production
- **Created From**: `main` (tagged release)
- **Merge To**: `main` and `develop`
- **Lifetime**: Until fix is released
- **Example**: `hotfix/fix-memory-leak`

### Workflow

#### Standard Release Flow
```
main
  ↓ (feature development)
feature/new-feature
  ↓ (PR and review)
main
  ↓ (code freeze)
release/v1.2.0
  ↓ (testing and fixes)
release/v1.2.0
  ↓ (release)
main (tagged v1.2.0)
```

#### Hotfix Flow
```
main (v1.2.0)
  ↓ (critical bug found)
hotfix/fix-bug
  ↓ (fix and test)
main (v1.2.1)
  ↓ (back-merge)
develop
```

## Support Policy

### Active Support

**Latest Major Version**: Full support
- New features
- Bug fixes
- Security patches
- Performance improvements
- Documentation updates

**Previous Major Version**: Maintenance support (6 months)
- Critical bug fixes
- Security patches
- No new features
- Limited support

### End of Life (EOL)

**Definition**: No longer receiving updates

**Timeline:**
- Major versions: EOL 6 months after next major release
- Minor versions: EOL when next minor is released
- Patch versions: EOL when next patch is released

**Example:**
- v2.0.0 released: v1.x enters maintenance mode
- v2.0.0 + 6 months: v1.x reaches EOL
- v2.1.0 released: v2.0.x no longer supported (upgrade to v2.1.x)

### Support Matrix

| Version | Status | Bug Fixes | Security | New Features | EOL Date |
|---------|--------|-----------|----------|--------------|----------|
| 2.0.x | Active | ✅ | ✅ | ✅ | - |
| 1.5.x | Maintenance | ⚠️ Critical Only | ✅ | ❌ | 2026-08-01 |
| 1.4.x | EOL | ❌ | ❌ | ❌ | 2026-02-01 |

## Deprecation Policy

### Deprecation Process

#### 1. Announcement (N Release)
- Feature/API marked as deprecated in code
- Deprecation warning in documentation
- Alternative approach documented
- CHANGELOG.md entry

```swift
@available(*, deprecated, message: "Use newMethod() instead. Will be removed in v3.0.0")
func oldMethod() { }
```

#### 2. Deprecation Period (N+1 Release)
- Feature still works but warns
- Documentation shows alternatives
- Migration guide available
- Community informed

#### 3. Removal (N+2 Release - Major Version Only)
- Feature removed from codebase
- Breaking change documented
- Migration guide mandatory
- Release notes highlight removal

### Deprecation Timeline

**Major API Changes:**
- Deprecated in: vX.Y.0
- Removed in: v(X+1).0.0 (next major)
- Minimum Period: 6-12 months

**Minor API Changes:**
- Deprecated in: vX.Y.0
- Removed in: v(X+1).0.0 (next major)
- Minimum Period: 3-6 months

**Internal APIs:**
- Can be changed without deprecation
- Not part of public API contract

### Deprecation Announcement

All deprecations must include:
1. **What**: Clearly state what is deprecated
2. **Why**: Explain the reason for deprecation
3. **When**: Specify removal version and timeline
4. **How**: Provide migration path and alternatives
5. **Example**: Show before/after code examples

## Release Checklist

### Pre-Release Checklist

#### Code Quality
- [ ] All tests pass (`swift test`)
- [ ] Code coverage ≥90%
- [ ] SwiftLint passes (zero errors)
- [ ] No compiler warnings (except acknowledged)
- [ ] Performance benchmarks pass
- [ ] Memory leak testing completed

#### Documentation
- [ ] API documentation complete (DocC)
- [ ] README.md updated
- [ ] CHANGELOG.md updated
- [ ] MIGRATION_GUIDE.md updated (if breaking changes)
- [ ] Code examples verified
- [ ] Tutorial videos updated (if applicable)

#### Security
- [ ] Security scan completed (CodeQL)
- [ ] Dependency vulnerabilities checked
- [ ] SECURITY_GUIDE.md reviewed
- [ ] No sensitive data in commits
- [ ] Encryption/authentication tested

#### Standards Compliance
- [ ] HL7 v2.x conformance verified
- [ ] HL7 v3.x conformance verified
- [ ] FHIR compliance tested
- [ ] COMPLIANCE_STATUS.md updated
- [ ] Interoperability tested

#### Release Preparation
- [ ] Version number updated in Package.swift
- [ ] Release notes drafted
- [ ] Migration guide reviewed
- [ ] Breaking changes documented
- [ ] Known issues documented

### Release Day Checklist

#### Final Testing
- [ ] Full test suite passed
- [ ] Clean build from scratch
- [ ] Documentation builds successfully
- [ ] Example code runs correctly
- [ ] CLI tool tested

#### Git Operations
- [ ] Create release tag: `git tag vX.Y.Z`
- [ ] Push tag: `git push origin vX.Y.Z`
- [ ] Merge release branch to main
- [ ] Back-merge to develop (if applicable)

#### GitHub Release
- [ ] Create GitHub release from tag
- [ ] Attach release notes
- [ ] Include upgrade instructions
- [ ] Highlight breaking changes
- [ ] Link to documentation

#### Documentation
- [ ] Publish updated documentation
- [ ] Update online examples
- [ ] Verify documentation links
- [ ] Update badges in README.md

#### Communication
- [ ] Announcement in GitHub Discussions
- [ ] Update project website (if applicable)
- [ ] Notify key stakeholders
- [ ] Social media announcement (if applicable)
- [ ] Blog post (for major releases)

### Post-Release Checklist

#### Monitoring (First 48 Hours)
- [ ] Monitor GitHub Issues
- [ ] Check CI/CD for failures
- [ ] Review download/usage metrics
- [ ] Respond to community feedback
- [ ] Address critical bugs immediately

#### Follow-Up (First Week)
- [ ] Triage new issues
- [ ] Plan hotfix if needed
- [ ] Update FAQ based on questions
- [ ] Collect feedback for retrospective
- [ ] Begin planning next release

#### Retrospective (Within 2 Weeks)
- [ ] Review release process
- [ ] Document lessons learned
- [ ] Update release procedures
- [ ] Celebrate successes
- [ ] Plan improvements

## Communication

### Release Announcements

**Channels:**
- GitHub Releases (primary)
- GitHub Discussions
- Project README.md
- CHANGELOG.md
- Social media (for major releases)

**Content:**
- Version number
- Release type (major/minor/patch)
- Key features or fixes
- Breaking changes (if any)
- Upgrade instructions
- Known issues
- Thank you to contributors

### Release Notes Template

```markdown
# HL7kit vX.Y.Z

## Release Type
[Major/Minor/Patch] Release

## Release Date
YYYY-MM-DD

## Highlights
- Feature 1: Description
- Feature 2: Description
- Bug Fix: Description

## Breaking Changes
- Change 1: Description and migration path
- Change 2: Description and migration path

## New Features
- Feature A (#123)
- Feature B (#456)

## Bug Fixes
- Fixed issue X (#789)
- Fixed issue Y (#101)

## Performance Improvements
- Improvement 1 (25% faster)
- Improvement 2 (30% less memory)

## Documentation
- Updated guides
- New examples

## Upgrade Instructions
1. Update Package.swift dependency
2. Run `swift package update`
3. See MIGRATION_GUIDE.md for breaking changes

## Known Issues
- Issue A (workaround: ...)
- Issue B (fix planned for vX.Y.Z+1)

## Contributors
Thank you to all contributors:
- @contributor1
- @contributor2

Full Changelog: vX.Y.Z-1...vX.Y.Z
```

## Emergency Procedures

### Critical Security Vulnerability

**Process:**
1. **Immediate Response** (Day 0)
   - Acknowledge receipt within 2 hours
   - Assess severity and impact
   - Create private security patch

2. **Development** (Days 1-2)
   - Develop fix in private branch
   - Test thoroughly
   - Prepare security advisory

3. **Coordinated Disclosure** (Days 3-7)
   - Notify affected users privately
   - Allow time for patching
   - Prepare public disclosure

4. **Release** (Day 7+)
   - Release security patch
   - Publish security advisory
   - Update SECURITY_GUIDE.md
   - Monitor for issues

### Critical Production Bug

**Process:**
1. **Verification** (Hours 0-4)
   - Confirm bug is critical
   - Assess impact
   - Determine if hotfix needed

2. **Hotfix Development** (Hours 4-12)
   - Create hotfix branch
   - Implement minimal fix
   - Test rigorously

3. **Expedited Release** (Hours 12-24)
   - Create hotfix release
   - Update documentation
   - Notify users
   - Monitor deployment

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2026-02-15 | Initial release cadence document |

## Questions and Feedback

For questions about releases:
- Check CHANGELOG.md for recent changes
- Review GitHub Milestones for upcoming releases
- Ask in GitHub Discussions
- Contact maintainers

---

**Document Version**: 1.0.0  
**Last Updated**: 2026-02-15  
**Next Review**: 2027-02-15

---

*This release cadence is designed to balance stability with innovation, providing predictable releases while maintaining the flexibility needed for security and critical fixes.*
