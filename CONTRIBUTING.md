# Contributing to Get-AzVMAvailability

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

- Check existing issues before creating a new one
- Use a clear, descriptive title
- Include PowerShell version, Az module versions, and OS
- Provide steps to reproduce the issue
- Include relevant error messages or screenshots

### Suggesting Enhancements

- Open an issue with the "enhancement" label
- Describe the use case and expected behavior
- Explain why this would be useful to other users

### Pull Requests

1. Fork the repository
2. Create a feature branch (git checkout -b feature/amazing-feature)
3. Make your changes
4. Test thoroughly with different scenarios
5. Commit with clear messages (git commit -m Add amazing feature)
6. Push to your branch (git push origin feature/amazing-feature)
7. Open a Pull Request

## Development Setup

    # Clone your fork
    git clone https://github.com/zacharyluz/Get-AzVMAvailability.git
    cd Get-AzVMAvailability

    # Install dependencies
    Install-Module -Name Az.Compute -Scope CurrentUser
    Install-Module -Name Az.Resources -Scope CurrentUser
    Install-Module -Name ImportExcel -Scope CurrentUser

## Code Style

- Use consistent indentation (4 spaces)
- Follow PowerShell best practices
- Add comments for complex logic
- Use meaningful variable names
- Include help documentation for new parameters

## Testing

Before submitting a PR, test with:
- Multiple subscriptions
- Various regions
- Both interactive and automated modes
- CSV and XLSX exports
- Unicode and ASCII terminal modes

## Questions?

Feel free to [open an issue](https://github.com/ZacharyLuz/Get-AzVMAvailability/issues) on GitHub.
