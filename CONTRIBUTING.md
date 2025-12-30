# Contributing to Project Cortex

Thank you for your interest in contributing to Project Cortex! This document provides guidelines for contributing to the project.

## Code of Conduct

Be respectful, collaborative, and constructive. This is an open-source research project focused on AI and game development.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Your environment (OS, Python version, etc.)

### Suggesting Features

Feature requests are welcome! Please:
- Check existing issues first
- Explain the use case
- Consider how it fits the project philosophy: "Do not cheat. Perceive, Predict, Perform."

### Code Contributions

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**
4. **Test your changes**: Ensure the QuakeC compiles and Python runs
5. **Commit with clear messages**: Follow conventional commits format
6. **Push and create a Pull Request**

## Development Setup

### Prerequisites

- Python 3.7+
- FTEQW compiler (included in `quakec/fteqcc64.exe`)
- Git

### Building

```bash
# Compile QuakeC
scripts\build.bat

# File IPC brain (tail telemetry file)
python cortex_brain.py
```

### Testing

```bash
# Run the telemetry visualizer (optional; requires pygame)
python cortex_visualizer.py

# Launch Quake and verify file IPC connection
scripts\run_quake.bat

# TCP stream mode (experimental: control + RL)
scripts\run_quake_tcp.bat
python train_cortex.py
```

## Project Structure

```
quakec/cortex/     - Custom QuakeC modules (sensors, bridge, etc.)
python/            - Python AI brain
                 (Gym env + training modules; repo root scripts are entrypoints)
scripts/           - Build and run scripts
docs/              - Documentation
```

## Coding Standards

### Python

- Follow PEP 8 style guide
- Use meaningful variable names
- Add docstrings to functions
- Keep functions focused and small
- Run `ruff check` before committing

### QuakeC

- Follow existing code style
- Add comments for complex logic
- Test compilation before committing
- Keep sensor code separate from bridge code

## Git Commit Messages

Use conventional commits format:

```
feat: Add new raycast sensor
fix: Fix file telemetry tailing
docs: Update quickstart guide
refactor: Simplify sensor data encoding
```

## Areas Needing Help

- **Phase 2**: Movement policy neural network (PPO implementation)
- **Phase 2**: Control input stream (Python → Quake)
- **Phase 3**: LLM integration for bot personality
- **Phase 3**: Text-to-speech pipeline
- **Testing**: Unit tests for Python code
- **Documentation**: Tutorials and examples
- **Performance**: Optimization of raycast system

## Questions?

Open an issue or discussion on GitHub. We're happy to help!

## License

By contributing, you agree that your contributions will be licensed under GPLv2, matching the project's license.
