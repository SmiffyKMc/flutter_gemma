# AGENT GUIDELINES

This repository uses a local Flutter SDK located in the `flutter/` directory. The
`flutter/` directory is excluded from version control via `.gitignore`, but it is
available in the environment. Invoke Flutter commands using `./flutter/bin/flutter`.

During each run, follow this workflow:

1. **Analyze** the project with `./flutter/bin/flutter analyze`.
2. **Update** or create code and documentation as needed.
3. **Analyze** again to ensure no analysis issues remain.
4. **Run tests** with `./flutter/bin/flutter test`.
5. **Fix** any issues until analysis and tests pass.
6. **Add or update tests** when introducing new behavior.