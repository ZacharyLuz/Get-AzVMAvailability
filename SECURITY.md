# Security Policy

> **This is a personal open-source project, not an official Microsoft product.** Do not report security issues or vulnerabilities to the Microsoft Security Response Center (MSRC). Please use this repository's reporting process below.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.6.x   | :white_check_mark: |
| 1.5.x   | :white_check_mark: |
| 1.4.x   | :white_check_mark: |
| 1.3.x   | :white_check_mark: |
| 1.2.x   | :white_check_mark: |
| 1.1.x   | :white_check_mark: |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability within this project, please report it via [GitHub Security Advisories](https://github.com/ZacharyLuz/Get-AzVMAvailability/security/advisories/new).

**Please do not report security vulnerabilities through public GitHub issues.**

You should receive a response within 48 hours. If the issue is confirmed, we will release a patch as soon as possible depending on complexity.

## Security Best Practices

When using this tool:

1. **Never commit Azure credentials** to version control
2. **Use managed identities** when running in Azure environments
3. **Limit subscription access** to only what's needed
4. **Review exported files** before sharing - they contain subscription IDs and region data
5. **Don't run untrusted scripts** - always review code before execution

## Scope

This tool:
- ✅ Reads Azure VM SKU information (read-only)
- ✅ Reads quota/usage information (read-only)
- ❌ Does NOT create, modify, or delete any Azure resources
- ❌ Does NOT store or transmit credentials
- ❌ Does NOT access sensitive data beyond SKU/quota info
