import SwiftUI
import AppKit
import AVFoundation

// MARK: - Sound Manager

class SoundManager: ObservableObject {
    @Published var soundEnabled: Bool = true

    private var dropPlayer: AVAudioPlayer?
    private var winPlayer: AVAudioPlayer?

    func playDrop() {
        guard soundEnabled else { return }
        NSSound(named: "Pop")?.play()
    }

    func playWin() {
        guard soundEnabled else { return }
        NSSound(named: "Glass")?.play()
    }

    func playDraw() {
        guard soundEnabled else { return }
        NSSound(named: "Basso")?.play()
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Theme Colors

struct GameColors {
    static let boardBlue = Color(red: 0.15, green: 0.35, blue: 0.65)
    static let boardBlueDark = Color(red: 0.1, green: 0.25, blue: 0.5)
    static let boardBlueLight = Color(red: 0.25, green: 0.5, blue: 0.8)

    static let pieceRed = Color(red: 0.9, green: 0.2, blue: 0.2)
    static let pieceRedDark = Color(red: 0.7, green: 0.1, blue: 0.1)
    static let pieceRedLight = Color(red: 1.0, green: 0.4, blue: 0.4)

    static let pieceYellow = Color(red: 1.0, green: 0.8, blue: 0.1)
    static let pieceYellowDark = Color(red: 0.85, green: 0.65, blue: 0.0)
    static let pieceYellowLight = Color(red: 1.0, green: 0.95, blue: 0.5)

    // Theme-aware colors
    static func background(for scheme: ColorScheme) -> (top: Color, bottom: Color) {
        switch scheme {
        case .dark:
            return (Color(red: 0.12, green: 0.14, blue: 0.18), Color(red: 0.08, green: 0.1, blue: 0.14))
        case .light:
            return (Color(red: 0.92, green: 0.94, blue: 0.96), Color(red: 0.85, green: 0.88, blue: 0.92))
        @unknown default:
            return (Color(red: 0.12, green: 0.14, blue: 0.18), Color(red: 0.08, green: 0.1, blue: 0.14))
        }
    }

    static func slotBackground(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(red: 0.06, green: 0.08, blue: 0.12)
        case .light:
            return Color(red: 0.2, green: 0.22, blue: 0.28)
        @unknown default:
            return Color(red: 0.06, green: 0.08, blue: 0.12)
        }
    }

    static func textColor(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return .white
        case .light:
            return Color(red: 0.15, green: 0.15, blue: 0.2)
        @unknown default:
            return .white
        }
    }

    static func subtleBackground(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color.white.opacity(0.05)
        case .light:
            return Color.black.opacity(0.05)
        @unknown default:
            return Color.white.opacity(0.05)
        }
    }
}

// MARK: - Models

enum Player: String, CaseIterable {
    case red = "Red"
    case yellow = "Yellow"

    var color: Color {
        switch self {
        case .red: return GameColors.pieceRed
        case .yellow: return GameColors.pieceYellow
        }
    }

    var lightColor: Color {
        switch self {
        case .red: return GameColors.pieceRedLight
        case .yellow: return GameColors.pieceYellowLight
        }
    }

    var darkColor: Color {
        switch self {
        case .red: return GameColors.pieceRedDark
        case .yellow: return GameColors.pieceYellowDark
        }
    }

    var opponent: Player {
        self == .red ? .yellow : .red
    }
}

enum GameMode: String, CaseIterable {
    case onePlayer = "vs Computer"
    case twoPlayers = "2 Players"
}

enum GameResult: Equatable {
    case ongoing
    case win(Player)
    case draw
}

// MARK: - Game State

class GameState: ObservableObject {
    static let rows = 6
    static let columns = 7

    @Published var board: [[Player?]]
    @Published var currentPlayer: Player = .red
    @Published var gameMode: GameMode = .twoPlayers
    @Published var gameResult: GameResult = .ongoing
    @Published var winningCells: [(row: Int, col: Int)] = []
    @Published var lastDroppedPosition: (row: Int, col: Int)? = nil
    @Published var isAnimating: Bool = false
    @Published var scores: [Player: Int] = [.red: 0, .yellow: 0]

    init() {
        board = Array(repeating: Array(repeating: nil, count: GameState.columns), count: GameState.rows)
    }

    func reset() {
        board = Array(repeating: Array(repeating: nil, count: GameState.columns), count: GameState.rows)
        currentPlayer = .red
        gameResult = .ongoing
        winningCells = []
        lastDroppedPosition = nil
        isAnimating = false
    }

    func canDrop(in column: Int) -> Bool {
        guard column >= 0 && column < GameState.columns else { return false }
        return board[0][column] == nil && gameResult == .ongoing && !isAnimating
    }

    func getDropRow(for column: Int) -> Int? {
        for row in (0..<GameState.rows).reversed() {
            if board[row][column] == nil {
                return row
            }
        }
        return nil
    }

    func dropPiece(in column: Int) {
        guard canDrop(in: column), let row = getDropRow(for: column) else { return }

        isAnimating = true
        board[row][column] = currentPlayer
        lastDroppedPosition = (row, column)

        if let winCells = checkWin(row: row, col: column) {
            winningCells = winCells
            gameResult = .win(currentPlayer)
            scores[currentPlayer, default: 0] += 1
            isAnimating = false
            return
        }

        if isBoardFull() {
            gameResult = .draw
            isAnimating = false
            return
        }

        currentPlayer = currentPlayer.opponent
        isAnimating = false

        if gameMode == .onePlayer && currentPlayer == .yellow && gameResult == .ongoing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.makeAIMove()
            }
        }
    }

    func isBoardFull() -> Bool {
        for col in 0..<GameState.columns {
            if board[0][col] == nil {
                return false
            }
        }
        return true
    }

    func checkWin(row: Int, col: Int) -> [(row: Int, col: Int)]? {
        guard let player = board[row][col] else { return nil }

        let directions: [(dr: Int, dc: Int)] = [
            (0, 1), (1, 0), (1, 1), (1, -1)
        ]

        for (dr, dc) in directions {
            var cells: [(row: Int, col: Int)] = [(row, col)]

            var r = row + dr
            var c = col + dc
            while r >= 0 && r < GameState.rows && c >= 0 && c < GameState.columns && board[r][c] == player {
                cells.append((r, c))
                r += dr
                c += dc
            }

            r = row - dr
            c = col - dc
            while r >= 0 && r < GameState.rows && c >= 0 && c < GameState.columns && board[r][c] == player {
                cells.append((r, c))
                r -= dr
                c -= dc
            }

            if cells.count >= 4 {
                return cells
            }
        }

        return nil
    }

    // MARK: - AI Logic

    func makeAIMove() {
        guard gameResult == .ongoing else { return }

        isAnimating = true
        let bestCol = findBestMove()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isAnimating = false
            self?.dropPiece(in: bestCol)
        }
    }

    func findBestMove() -> Int {
        var bestScore = Int.min
        var bestCol = 3

        for col in [3, 2, 4, 1, 5, 0, 6] {
            guard canDropForAI(in: col) else { continue }

            let row = getDropRow(for: col)!
            board[row][col] = .yellow

            let score = minimax(depth: 5, alpha: Int.min, beta: Int.max, isMaximizing: false)

            board[row][col] = nil

            if score > bestScore {
                bestScore = score
                bestCol = col
            }
        }

        return bestCol
    }

    func canDropForAI(in column: Int) -> Bool {
        guard column >= 0 && column < GameState.columns else { return false }
        return board[0][column] == nil
    }

    func minimax(depth: Int, alpha: Int, beta: Int, isMaximizing: Bool) -> Int {
        if let winner = checkWinnerForAI() {
            return winner == .yellow ? 10000 + depth : -10000 - depth
        }

        if isBoardFull() { return 0 }
        if depth == 0 { return evaluateBoard() }

        var alpha = alpha
        var beta = beta

        if isMaximizing {
            var maxScore = Int.min
            for col in 0..<GameState.columns {
                guard canDropForAI(in: col) else { continue }
                let row = getDropRow(for: col)!
                board[row][col] = .yellow
                let score = minimax(depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: false)
                board[row][col] = nil
                maxScore = max(maxScore, score)
                alpha = max(alpha, score)
                if beta <= alpha { break }
            }
            return maxScore
        } else {
            var minScore = Int.max
            for col in 0..<GameState.columns {
                guard canDropForAI(in: col) else { continue }
                let row = getDropRow(for: col)!
                board[row][col] = .red
                let score = minimax(depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: true)
                board[row][col] = nil
                minScore = min(minScore, score)
                beta = min(beta, score)
                if beta <= alpha { break }
            }
            return minScore
        }
    }

    func checkWinnerForAI() -> Player? {
        for row in 0..<GameState.rows {
            for col in 0..<GameState.columns {
                if board[row][col] != nil && checkWin(row: row, col: col) != nil {
                    return board[row][col]
                }
            }
        }
        return nil
    }

    func evaluateBoard() -> Int {
        var score = 0
        let centerCol = GameState.columns / 2
        for row in 0..<GameState.rows {
            if board[row][centerCol] == .yellow { score += 3 }
            else if board[row][centerCol] == .red { score -= 3 }
        }
        score += evaluateWindows()
        return score
    }

    func evaluateWindows() -> Int {
        var score = 0

        for row in 0..<GameState.rows {
            for col in 0..<(GameState.columns - 3) {
                let window = (0..<4).map { board[row][col + $0] }
                score += evaluateWindow(window)
            }
        }

        for row in 0..<(GameState.rows - 3) {
            for col in 0..<GameState.columns {
                let window = (0..<4).map { board[row + $0][col] }
                score += evaluateWindow(window)
            }
        }

        for row in 3..<GameState.rows {
            for col in 0..<(GameState.columns - 3) {
                let window = (0..<4).map { board[row - $0][col + $0] }
                score += evaluateWindow(window)
            }
        }

        for row in 0..<(GameState.rows - 3) {
            for col in 0..<(GameState.columns - 3) {
                let window = (0..<4).map { board[row + $0][col + $0] }
                score += evaluateWindow(window)
            }
        }

        return score
    }

    func evaluateWindow(_ window: [Player?]) -> Int {
        let yellowCount = window.filter { $0 == .yellow }.count
        let redCount = window.filter { $0 == .red }.count
        let emptyCount = window.filter { $0 == nil }.count

        if yellowCount == 4 { return 100 }
        if yellowCount == 3 && emptyCount == 1 { return 5 }
        if yellowCount == 2 && emptyCount == 2 { return 2 }
        if redCount == 4 { return -100 }
        if redCount == 3 && emptyCount == 1 { return -4 }

        return 0
    }
}

// MARK: - Views

struct PieceView: View {
    let player: Player
    let isWinning: Bool
    let animate: Bool
    let size: CGFloat

    @State private var dropOffset: CGFloat = -500
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Outer glow for winning pieces
            if isWinning {
                Circle()
                    .fill(player.color)
                    .blur(radius: 12)
                    .opacity(glowOpacity)
                    .scaleEffect(1.3)
            }

            // Main piece with 3D effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: player.lightColor, location: 0.0),
                            .init(color: player.color, location: 0.35),
                            .init(color: player.darkColor, location: 1.0)
                        ]),
                        center: .init(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .overlay(
                    // Specular highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.0)
                                ]),
                                center: .init(x: 0.3, y: 0.25),
                                startRadius: 0,
                                endRadius: size * 0.25
                            )
                        )
                        .scaleEffect(0.85)
                )
                .overlay(
                    // Inner edge definition
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [player.darkColor.opacity(0.5), Color.clear],
                                startPoint: .bottom,
                                endPoint: .top
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 3, x: 2, y: 3)
        }
        .scaleEffect(isWinning ? pulseScale : 1.0)
        .offset(y: animate ? dropOffset : 0)
        .onAppear {
            if animate {
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                    dropOffset = 0
                }
            }
            if isWinning {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                    glowOpacity = 0.8
                }
            }
        }
    }
}

struct SlotView: View {
    let row: Int
    let col: Int
    let player: Player?
    let isWinning: Bool
    let isLastDropped: Bool
    let isHovered: Bool
    let hoverPlayer: Player
    let slotSize: CGFloat
    var colorScheme: ColorScheme = .dark

    var body: some View {
        ZStack {
            // Slot hole with inset effect
            Circle()
                .fill(GameColors.slotBackground(for: colorScheme))
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.6),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)

            // Hover preview
            if isHovered && player == nil {
                Circle()
                    .fill(hoverPlayer.color.opacity(0.35))
                    .padding(4)
                    .transition(.opacity)
            }

            // Game piece
            if let player = player {
                PieceView(
                    player: player,
                    isWinning: isWinning,
                    animate: isLastDropped,
                    size: slotSize
                )
                .padding(5)
            }
        }
    }
}

struct BoardView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var soundManager: SoundManager
    @State private var hoveredColumn: Int? = nil
    var colorScheme: ColorScheme = .dark

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height - 40
            let availableWidth = geometry.size.width - 20
            let slotFromHeight = availableHeight / (CGFloat(GameState.rows) + 1.8)
            let slotFromWidth = availableWidth / (CGFloat(GameState.columns) + 0.8)
            let slotSize = min(min(slotFromHeight, slotFromWidth), 60)
            let spacing = max(slotSize * 0.12, 4)
            let cornerRadius = slotSize * 0.3

            let boardWidth = (slotSize + spacing) * CGFloat(GameState.columns) + spacing * 3

            HStack {
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                // Hover indicator row
                HStack(spacing: spacing) {
                    ForEach(0..<GameState.columns, id: \.self) { col in
                        ZStack {
                            Circle()
                                .fill(Color.clear)

                            if hoveredColumn == col && gameState.canDrop(in: col) {
                                PieceView(
                                    player: gameState.currentPlayer,
                                    isWinning: false,
                                    animate: false,
                                    size: slotSize - 8
                                )
                                .opacity(0.85)
                                .shadow(color: gameState.currentPlayer.color.opacity(0.6), radius: 8)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: slotSize, height: slotSize)
                        .animation(.easeOut(duration: 0.15), value: hoveredColumn)
                    }
                }
                .padding(.horizontal, spacing * 2)
                .padding(.bottom, spacing)

                // Game board with frame
                ZStack {
                    // Board outer frame
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: GameColors.boardBlueLight, location: 0.0),
                                    .init(color: GameColors.boardBlue, location: 0.3),
                                    .init(color: GameColors.boardBlueDark, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1),
                                            Color.black.opacity(0.2)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 8)

                    // Grid of slots
                    VStack(spacing: spacing) {
                        ForEach(0..<GameState.rows, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<GameState.columns, id: \.self) { col in
                                    SlotView(
                                        row: row,
                                        col: col,
                                        player: gameState.board[row][col],
                                        isWinning: gameState.winningCells.contains { $0.row == row && $0.col == col },
                                        isLastDropped: gameState.lastDroppedPosition?.row == row && gameState.lastDroppedPosition?.col == col,
                                        isHovered: hoveredColumn == col,
                                        hoverPlayer: gameState.currentPlayer,
                                        slotSize: slotSize,
                                        colorScheme: colorScheme
                                    )
                                    .frame(width: slotSize, height: slotSize)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if gameState.canDrop(in: col) {
                                            gameState.dropPiece(in: col)
                                            soundManager.playDrop()
                                            // Check for win/draw after drop
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                                if case .win = gameState.gameResult {
                                                    soundManager.playWin()
                                                } else if case .draw = gameState.gameResult {
                                                    soundManager.playDraw()
                                                }
                                            }
                                        }
                                    }
                                    .onHover { hovering in
                                        withAnimation(.easeOut(duration: 0.1)) {
                                            if hovering {
                                                hoveredColumn = col
                                            } else if hoveredColumn == col {
                                                hoveredColumn = nil
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(spacing * 2)
                }

                // Board stand/base
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    GameColors.boardBlueDark,
                                    GameColors.boardBlueDark.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(slotSize * 0.35, 16))
                        .padding(.horizontal, slotSize * 0.6)
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 4)
                }
                .offset(y: -4)
                }
                .frame(width: boardWidth)
                Spacer(minLength: 0)
            }
        }
    }
}

struct GameOverView: View {
    let result: GameResult
    let onNewGame: () -> Void

    @State private var showContent = false

    var title: String {
        switch result {
        case .win(let player):
            return "\(player.rawValue) Wins!"
        case .draw:
            return "It's a Draw!"
        case .ongoing:
            return ""
        }
    }

    var titleColor: Color {
        switch result {
        case .win(let player):
            return player.color
        case .draw:
            return .white
        case .ongoing:
            return .white
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [titleColor, titleColor.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: titleColor.opacity(0.5), radius: 10)
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 2)

            Button(action: onNewGame) {
                Text("Play Again")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        GameColors.boardBlueLight,
                                        GameColors.boardBlue
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: GameColors.boardBlue.opacity(0.5), radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .scaleEffect(showContent ? 1.0 : 0.8)
        }
        .padding(50)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20)
        )
        .scaleEffect(showContent ? 1.0 : 0.9)
        .opacity(showContent ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showContent = true
            }
        }
    }
}

struct PlayerIndicator: View {
    let player: Player
    let score: Int
    let isActive: Bool
    let label: String
    var compact: Bool = false
    var colorScheme: ColorScheme = .dark

    var body: some View {
        let pieceSize: CGFloat = compact ? 32 : 44
        let frameSize: CGFloat = compact ? 44 : 60
        let scoreSize: CGFloat = compact ? 22 : 28
        let labelSize: CGFloat = compact ? 10 : 12
        let textColor = GameColors.textColor(for: colorScheme)

        VStack(spacing: compact ? 4 : 8) {
            Text(label)
                .font(.system(size: labelSize, weight: .medium, design: .rounded))
                .foregroundColor(textColor.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1)

            ZStack {
                // Glow effect for active player
                if isActive {
                    Circle()
                        .fill(player.color)
                        .blur(radius: compact ? 10 : 15)
                        .opacity(0.6)
                        .scaleEffect(1.2)
                }

                // Piece representation
                PieceView(
                    player: player,
                    isWinning: false,
                    animate: false,
                    size: pieceSize
                )
                .frame(width: pieceSize, height: pieceSize)
            }
            .frame(width: frameSize, height: frameSize)

            Text("\(score)")
                .font(.system(size: scoreSize, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .padding(.vertical, compact ? 8 : 12)
        .padding(.horizontal, compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: compact ? 12 : 16)
                .fill(isActive ? player.color.opacity(0.15) : GameColors.subtleBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 12 : 16)
                        .strokeBorder(
                            isActive ? player.color.opacity(0.5) : textColor.opacity(0.1),
                            lineWidth: isActive ? 2 : 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

struct GameModeButton: View {
    let mode: GameMode
    let isSelected: Bool
    var colorScheme: ColorScheme = .dark
    let action: () -> Void

    var body: some View {
        let textColor = GameColors.textColor(for: colorScheme)
        Button(action: action) {
            Text(mode.rawValue)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : textColor.opacity(0.6))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? GameColors.boardBlue : GameColors.subtleBackground(for: colorScheme))
                )
        }
        .buttonStyle(.plain)
    }
}

struct AppearanceButton: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: mode.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : GameColors.textColor(for: colorScheme).opacity(0.5))
                .frame(width: 36, height: 28)
                .background(
                    Capsule()
                        .fill(isSelected ? GameColors.boardBlue : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(mode.rawValue)
    }
}

struct SoundToggleButton: View {
    @Binding var soundEnabled: Bool
    let colorScheme: ColorScheme

    var body: some View {
        Button(action: {
            soundEnabled.toggle()
        }) {
            Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GameColors.textColor(for: colorScheme).opacity(0.6))
                .frame(width: 36, height: 28)
        }
        .buttonStyle(.plain)
        .help(soundEnabled ? "Sound On" : "Sound Off")
    }
}

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @StateObject private var soundManager = SoundManager()
    @State private var appearanceMode: AppearanceMode = .system
    @Environment(\.colorScheme) private var systemColorScheme

    var effectiveColorScheme: ColorScheme {
        appearanceMode.colorScheme ?? systemColorScheme
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 650
            let titleSize: CGFloat = isCompact ? 28 : 36
            let spacing: CGFloat = isCompact ? 12 : 20
            let padding: CGFloat = isCompact ? 16 : 24
            let colors = GameColors.background(for: effectiveColorScheme)
            let textColor = GameColors.textColor(for: effectiveColorScheme)

            ZStack {
                // Rich gradient background
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: colors.top, location: 0.0),
                        .init(color: colors.bottom, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Subtle pattern overlay
                Canvas { context, size in
                    let dotColor = effectiveColorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.02)
                    for i in stride(from: 0, to: size.width, by: 40) {
                        for j in stride(from: 0, to: size.height, by: 40) {
                            let rect = CGRect(x: i, y: j, width: 1, height: 1)
                            context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                        }
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: spacing) {
                    // Top bar with sound and appearance toggles
                    HStack {
                        // Sound toggle
                        HStack(spacing: 2) {
                            SoundToggleButton(
                                soundEnabled: $soundManager.soundEnabled,
                                colorScheme: effectiveColorScheme
                            )
                        }
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(GameColors.subtleBackground(for: effectiveColorScheme))
                        )

                        Spacer()

                        // Appearance toggle
                        HStack(spacing: 2) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                AppearanceButton(
                                    mode: mode,
                                    isSelected: appearanceMode == mode,
                                    colorScheme: effectiveColorScheme
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appearanceMode = mode
                                    }
                                }
                            }
                        }
                        .padding(4)
                        .background(
                            Capsule()
                                .fill(GameColors.subtleBackground(for: effectiveColorScheme))
                        )
                    }

                    // Header
                    Text("CONNECT FOUR")
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [textColor, textColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .tracking(3)
                        .shadow(color: GameColors.boardBlue.opacity(0.5), radius: 10)

                    // Game mode selector
                    HStack(spacing: 8) {
                        ForEach(GameMode.allCases, id: \.self) { mode in
                            GameModeButton(
                                mode: mode,
                                isSelected: gameState.gameMode == mode,
                                colorScheme: effectiveColorScheme
                            ) {
                                if gameState.gameMode != mode {
                                    gameState.gameMode = mode
                                    gameState.reset()
                                }
                            }
                        }
                    }
                    .padding(4)
                    .background(
                        Capsule()
                            .fill(GameColors.subtleBackground(for: effectiveColorScheme))
                    )

                    // Score display
                    HStack(spacing: isCompact ? 24 : 40) {
                        PlayerIndicator(
                            player: .red,
                            score: gameState.scores[.red] ?? 0,
                            isActive: gameState.currentPlayer == .red && gameState.gameResult == .ongoing,
                            label: gameState.gameMode == .onePlayer ? "You" : "Red",
                            compact: isCompact,
                            colorScheme: effectiveColorScheme
                        )

                        VStack {
                            Text("VS")
                                .font(.system(size: isCompact ? 14 : 16, weight: .bold, design: .rounded))
                                .foregroundColor(textColor.opacity(0.3))
                        }

                        PlayerIndicator(
                            player: .yellow,
                            score: gameState.scores[.yellow] ?? 0,
                            isActive: gameState.currentPlayer == .yellow && gameState.gameResult == .ongoing,
                            label: gameState.gameMode == .onePlayer ? "CPU" : "Yellow",
                            compact: isCompact,
                            colorScheme: effectiveColorScheme
                        )
                    }

                    // Game board
                    BoardView(gameState: gameState, soundManager: soundManager, colorScheme: effectiveColorScheme)
                        .layoutPriority(1)

                    // New Game button
                    Button(action: { gameState.reset() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                            Text("New Game")
                                .font(.system(size: isCompact ? 12 : 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(textColor.opacity(0.8))
                        .padding(.horizontal, isCompact ? 18 : 24)
                        .padding(.vertical, isCompact ? 8 : 12)
                        .background(
                            Capsule()
                                .fill(GameColors.subtleBackground(for: effectiveColorScheme))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(textColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(padding)

                // Game over overlay
                if gameState.gameResult != .ongoing {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    GameOverView(result: gameState.gameResult) {
                        withAnimation {
                            gameState.reset()
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: gameState.gameResult)
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }
}

// MARK: - App Entry Point

@main
struct ConnectFourApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 420, minHeight: 580)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
