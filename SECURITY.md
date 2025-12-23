# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.2.x   | :white_check_mark: |
| < 0.2.0 | :x:                |

## Reporting a Vulnerability

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them responsibly by emailing:

**security@polyfence.io**

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

### What to Include

When reporting a vulnerability, please include:

- **Type of vulnerability** (e.g., unauthorized location access, data leak, etc.)
- **Full paths of affected files**
- **Step-by-step instructions** to reproduce the issue
- **Proof of concept** or exploit code (if possible)
- **Impact assessment** - how severe is this vulnerability?
- **Your contact information** for follow-up questions

### What to Expect

1. **Acknowledgment** within 48 hours
2. **Initial assessment** within 5 business days
3. **Regular updates** as we investigate and develop a fix
4. **Credit** in the security advisory (if you want)

### Our Commitment

- We will keep you informed throughout the process
- We will not take legal action against security researchers who follow this policy
- We will credit you in security advisories (unless you prefer anonymity)
- We aim to patch critical vulnerabilities within 7 days

## Security Best Practices

### For Developers Using Polyfence

1. **API Keys**
   - Never commit API keys to version control
   - Use environment variables or secure storage
   - Rotate keys regularly

2. **Location Data**
   - Polyfence stores zones locally (SharedPreferences/UserDefaults)
   - Zone data is NOT encrypted by default
   - For sensitive use cases, encrypt zone data before passing to Polyfence

3. **Analytics**
   - Analytics is opt-in only
   - No location data is sent without explicit configuration
   - Review `AnalyticsConfig` settings before enabling

4. **Permissions**
   - Request minimum necessary permissions
   - Explain to users why "Always" location is needed
   - Provide opt-out mechanisms

### Known Security Considerations

**Zone Data Storage**
- Zones are stored unencrypted in local storage
- Any app with file system access could theoretically read zone data
- **Mitigation**: Don't store sensitive information in zone metadata

**Location Privacy**
- Polyfence processes location data on-device
- No location data leaves the device by default
- **Mitigation**: Audit analytics configuration before enabling

**Background Tracking**
- iOS/Android require "Always" location permission for background geofencing
- Users should be informed about background tracking
- **Mitigation**: Clear privacy policy, obvious UI indicators

## Security Updates

Security updates will be released as patch versions (e.g., 0.2.1) and announced via:

- GitHub Security Advisories
- CHANGELOG.md
- pub.dev package notes

Subscribe to repository releases to get notifications.

## Third-Party Dependencies

We regularly audit our dependencies for security vulnerabilities:

- `http` - HTTP client (official Dart package)
- `shared_preferences` - Local storage (official Flutter package)
- `package_info_plus` - Package metadata (community package)
- `battery_plus` - Battery info (community package)
- `uuid` - UUID generation (community package)

All dependencies are from trusted sources and actively maintained.

## Contact

- **Security issues**: security@polyfence.io
- **General questions**: Open a GitHub issue with `question` label
- **Commercial support**: https://polyfence.io

Thank you for helping keep Polyfence and our users safe!
