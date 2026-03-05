# Release Automation Script

A robust Bash script to automate the release process for PreProd (Release Candidate tags) and Prod (Version tags) environments, ensuring user confirmation at every step.

## Installation

You can install the script using `curl`:

```bash
curl -sSL https://raw.githubusercontent.com/Danushka96/release-script/main/release.sh -o release.sh && chmod +x release.sh
```

To install it globally as `release`:

```bash
./release.sh install
```

## Usage

Run the script in interactive mode:

```bash
release
```

### CLI Commands

- `release install`: Install the script globally.
- `release version`: Show the current version.
- `release update`: Automatically update the script to the latest version from GitHub.
- `release help`: Show the help message.

## Features

- **Interactive Prompts**: Confirms every git command before execution.
- **Auto-increment Logic**: Automatically increments PreProd RC tags (e.g., `Y2026W05-RC1` -> `Y2026W05-RC2`).
- **Branch Management**: Identifies and creates release branches based on year/week when needed.
- **Environment Support**: Separate flows for PreProd (RC) and Prod (Version) releases.
- **Global Availability**: Can be installed to `/usr/local/bin` for quick access.
