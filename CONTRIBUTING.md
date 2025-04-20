# Contributing to FlashFind

Thank you for your interest in contributing to FlashFind! 

## How to Contribute

1. **Fork the repository** - Fork the FlashFind repository to your GitHub account.

2. **Create a feature branch** - Create a branch for your feature or bugfix.
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes** - Make changes following our coding style guidelines below.

4. **Test your changes** - Thoroughly test your changes on macOS.

5. **Submit a pull request** - Open a pull request against the `main` branch.

## Coding Style Guidelines

1. **Minimal Change Protocol**:
   - Make the smallest possible line changes per commit
   - Only change files directly needed for the task
   - Never remove code without explicit approval in your PR
   - Keep existing patterns unless refactoring is specifically approved

2. **Shell Script Best Practices**:
   - Use shellcheck to lint your Bash scripts
   - Document functions with clear comments
   - Handle errors and edge cases gracefully
   - Create meaningful error messages

3. **Commit Messages**:
   ```
   fix(scope): what changed (max 50 chars)
   - Changed: list specific lines
   - Tested: how verified
   - Risk: low/med/high + why
   ```

## Testing

Before submitting a PR, test your changes thoroughly on macOS:

- Test different file patterns and commands
- Test on both large and small directories
- Test with Spotlight indexing enabled and disabled
- Test fallback to standard find for complex operations

## Getting Started

Good first issues are marked with the `good-first-issue` label in our issue tracker.

## Code of Conduct

Be respectful and constructive in all interactions.

## Questions?

Feel free to open an issue if you have any questions about contributing.
