# Connect Four

A beautiful, native macOS Connect Four game built with SwiftUI.

![Connect Four Screenshot](screenshot.png)

## Features

- **Classic Gameplay**: Standard 7x6 Connect Four board
- **Two Game Modes**:
  - 2 Players (local multiplayer)
  - vs Computer (AI opponent with minimax algorithm)
- **Beautiful UI**:
  - 3D-styled game pieces with gradients and highlights
  - Smooth drop animations
  - Winning piece animations with glow effects
  - Hover previews showing where pieces will drop
- **Theme Support**: Light mode, dark mode, or system preference
- **Sound Effects**: Audio feedback for moves (can be toggled on/off)
- **Score Tracking**: Keeps track of wins between games
- **Responsive Design**: Window is resizable with adaptive layout

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for building)

## Quick Start

### Option 1: Build with Swift Compiler (No Xcode Required)

```bash
# Clone the repository
git clone https://github.com/yourusername/connect-four-opus.git
cd connect-four-opus

# Compile
swiftc -parse-as-library -o ConnectFour ConnectFour.swift \
    -framework SwiftUI -framework AppKit -framework AVFoundation

# Run
./ConnectFour
```

### Option 2: Build with Xcode

1. Open `ConnectFour.xcodeproj` in Xcode
2. Select your development team (or use "Sign to Run Locally")
3. Press `Cmd+R` to build and run

## Creating a Release Build

### Using Xcode

1. Open the project in Xcode
2. Select **Product > Archive**
3. In the Organizer, click **Distribute App**
4. Choose **Copy App** for direct distribution (no notarization)
5. Or choose **Developer ID** for notarized distribution

### Using Command Line

```bash
# Build release version
xcodebuild -project ConnectFour.xcodeproj \
    -scheme ConnectFour \
    -configuration Release \
    -derivedDataPath build \
    build

# The app will be at:
# build/Build/Products/Release/ConnectFour.app
```

### Creating a DMG for Distribution

```bash
# Create a DMG
hdiutil create -volname "Connect Four" \
    -srcfolder "build/Build/Products/Release/ConnectFour.app" \
    -ov -format UDZO \
    ConnectFour.dmg
```

## Project Structure

```
ConnectFour/
├── ConnectFour.swift          # Main source file (all game code)
├── ConnectFour.xcodeproj/     # Xcode project
├── Assets.xcassets/           # Asset catalog
│   └── AppIcon.appiconset/    # App icon images
├── generate_icon.swift        # Script to regenerate app icons
└── README.md                  # This file
```

## How to Play

1. **Start a Game**: Launch the app - you're ready to play!
2. **Choose Mode**: Select "2 Players" or "vs Computer" at the top
3. **Drop Pieces**: Click on a column to drop your piece
4. **Win**: Get four pieces in a row (horizontal, vertical, or diagonal)
5. **New Game**: Click "New Game" to start over (scores are preserved)

## AI Details

The computer opponent uses the **minimax algorithm** with **alpha-beta pruning**:
- Search depth: 5 moves ahead
- Evaluates positions based on:
  - Winning/losing positions
  - Center column preference
  - Connected piece patterns

## Customization

### Changing the AI Difficulty

In `ConnectFour.swift`, find the `minimax` call in `findBestMove()`:
```swift
let score = minimax(depth: 5, ...)  // Increase for harder AI
```

### Modifying Colors

Edit the `GameColors` struct at the top of the file to customize:
- Board colors
- Piece colors
- Background colors

## License

MIT License - feel free to use, modify, and distribute.

## Credits

Built with SwiftUI for macOS.

---

*Made with Claude Code*
