# Ferrous: macOS System Tray App Documentation

![transparent1.png](../ferrous/Assets.xcassets/TrayIcon.imageset/transparent1.png)

Ferrous is a lightweight macOS system tray application that integrates GitHub pull request monitoring, tool status checking, Kubernetes context management, and version update notifications. This documentation provides an overview of its features and usage for end users, as well as detailed guidance on how to extend or modify the app for developers and contributors.

## Features

### GitHub Pull Request Monitoring
* View open pull requests authored by you
* Track repository-specific pull requests
* Configure specific repositories for monitoring
* Separate Tier Zero view for critical repositories

### Tool Status Checking
* Monitor the status of various command-line tools:
  * `kubectl`, `helm`, `vpn`, `aws`, etc.
  * Configurable tools through YAML configuration
* Visual indicators (✅/❌) showing tool availability
* Automatic status refresh with configurable intervals

### Kubernetes Context Management
* Compare your current local Kubernetes context with the stable AWS EKS cluster
* One-click switch between contexts
* Visual indicator for context status

### Environment Variables
* View and search system environment variables
* Copy variable keys, values, or export statements
* Export all environment variables to a file
* Filter variables by search terms

### Custom Actions & Links
* Integrate with services like JumpCloud and SAML
* Configurable links to important resources
* Dynamic dropdown menus for profile selection

### System Integration
* Lightweight system tray integration
* Configurable refresh intervals (30s, 1m, 5m, 15m)
* Automatic version update notifications

## Installation

### Using Homebrew

```bash
brew tap onefootball/tap
brew install ferrous
```

### Manual Installation

1. Download the latest release from the [Releases page](https://github.com/onefootball/ferrous/releases)
2. Open the DMG file and drag Ferrous to your Applications folder
3. Launch Ferrous from Applications

### Building from Source

```bash
# Clone the repository
git clone https://github.com/onefootball/ferrous.git
cd ferrous

# Build the application
make build

# Install to Applications folder
make install
```

## Configuration

Ferrous is configured through a YAML file located at `~/.ferrous/config.yaml`. On first launch, if this file doesn't exist, Ferrous will prompt you to set up your GitHub credentials.

Example configuration:

```yaml
tierzero:
  github:
    user: "your-github-username"
    organisation: "onefootball"
    timezone: "Europe/Berlin"
    repositories:
      - onefootball/ferrous
      - onefootball/other-repo
  links:
    - name: Trusted Advisor
      url: https://us-east-1.console.aws.amazon.com/trustedadvisor/home

checker:
  tools:
    kubectl:
      title: kubectl
      help: "Check kubectl status"
      checkCommand: "which kubectl"
    helm:
      title: helm
      help: "Check helm status"
      checkCommand: "which helm"
```

### GitHub Token

To monitor pull requests, you'll need to provide a GitHub Personal Access Token with the `repo` scope. This is requested on first launch but can be updated by editing the token file at `~/Documents/github_token.txt`.

## Development

### Prerequisites

* macOS 12.0 or later
* Xcode 14.0 or later
* Swift 5.5 or later
* Make (for build tasks)

### Project Structure

```
Ferrous/
├── Ferrous/
│   ├── Models/         # Data models
│   ├── Views/          # SwiftUI views
│   ├── Services/       # API and tool services
│   ├── Managers/       # Business logic managers
│   ├── Utils/          # Utility classes
│   └── Resources/      # Assets and resources
├── Scripts/            # Build and packaging scripts
└── .github/            # CI/CD workflows
```

### Running Tests

```bash
make test
```

### Building a Release

```bash
make package
```

This will create both a DMG file and a PKG installer in the `dist` directory.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Copyright © 2025 Onefootball. All rights reserved.