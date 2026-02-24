# Contributing to Whisper Puma

We love your input! We want to make contributing to this project as easy and transparent as possible.

## Project Structure

This project follows the **Clean Root Pattern**:
- `src/ui/`: Contains the Swift macOS Menu Bar application.
- `src/backend/`: Contains the Python orchestration daemon.
- Do not place loose scripts or source code in the repository root.

## 8-Step Safe Modification Protocol

When submitting changes, please ensure you follow our rigid modification protocol:
1. **Read**: Fully understand the component you are modifying.
2. **Hash**: Verify the state of the codebase.
3. **Check**: Ensure changes align with the architecture (`docs/puma_spec.md`).
4. **Backup**: Maintain local backups of critical files.
5. **Apply**: Make your changes cleanly.
6. **Validate**: Ensure the code compiles and style guidelines are met.
7. **Test**: Run local tests (ensure the backend still receives audio correctly).
8. **Log**: Document all changes clearly in your Pull Request and the `CHANGELOG.md`.

## Pull Requests
- Provide a clear, descriptive title.
- Link any relevant open issues.
- Explain *why* the change is necessary, not just *what* it does.
