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

enum Difficulty: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    
    var searchDepth: Int {
        switch self {
        case .easy: return 2
        case .medium: return 4
        case .hard: return 6
        }
    }
    
    var icon: String {
        switch self {
        case .easy: return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard: return "bolt.fill"
        }
    }
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
    @Published var difficulty: Difficulty = .easy
    @Published var gameResult: GameResult = .ongoing
    @Published var winningCells: [(row: Int, col: Int)] = []
    @Published var scores: [Player: Int] = [.red: 0, .yellow: 0]

    // Non-published flag to prevent clicks during AI turn
    var isAIThinking: Bool = false

    init() {
        board = Array(repeating: Array(repeating: nil, count: GameState.columns), count: GameState.rows)
    }

    func reset() {
        board = Array(repeating: Array(repeating: nil, count: GameState.columns), count: GameState.rows)
        currentPlayer = .red
        gameResult = .ongoing
        winningCells = []
        isAIThinking = false
    }

    func canDrop(in column: Int) -> Bool {
        guard column >= 0 && column < GameState.columns else { return false }
        return board[0][column] == nil && gameResult == .ongoing && !isAIThinking
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

        board[row][column] = currentPlayer

        if let winCells = checkWin(row: row, col: column) {
            winningCells = winCells
            gameResult = .win(currentPlayer)
            scores[currentPlayer, default: 0] += 1
            return
        }

        if isBoardFull() {
            gameResult = .draw
            return
        }

        currentPlayer = currentPlayer.opponent

        if gameMode == .onePlayer && currentPlayer == .yellow && gameResult == .ongoing {
            isAIThinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
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

        // Copy the board for AI calculations (so we don't modify the displayed board)
        let boardCopy = board

        // Run AI on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let bestCol = self.findBestMove(board: boardCopy)

            DispatchQueue.main.async {
                self.isAIThinking = false
                if let row = self.getDropRow(for: bestCol) {
                    self.board[row][bestCol] = .yellow

                    if let winCells = self.checkWin(row: row, col: bestCol) {
                        self.winningCells = winCells
                        self.gameResult = .win(.yellow)
                        self.scores[.yellow, default: 0] += 1
                        return
                    }

                    if self.isBoardFull() {
                        self.gameResult = .draw
                        return
                    }

                    self.currentPlayer = .red
                }
            }
        }
    }

    // MARK: - AI with local board copy

    func findBestMove(board: [[Player?]]) -> Int {
        var searchBoard = board
        var bestScore = Int.min
        var bestCol = 3

        // For easy mode, add some randomness
        let shouldMakeRandomMove = difficulty == .easy && Int.random(in: 0...100) < 30
        
        if shouldMakeRandomMove {
            // 30% chance to make a random valid move on easy
            let validColumns = (0..<GameState.columns).filter { searchBoard[0][$0] == nil }
            if !validColumns.isEmpty {
                return validColumns.randomElement()!
            }
        }

        for col in [3, 2, 4, 1, 5, 0, 6] {
            guard searchBoard[0][col] == nil else { continue }

            let row = getDropRowAI(board: searchBoard, col: col)!
            searchBoard[row][col] = .yellow

            let score = minimaxAI(board: &searchBoard, depth: difficulty.searchDepth, alpha: Int.min, beta: Int.max, isMaximizing: false)

            searchBoard[row][col] = nil

            if score > bestScore {
                bestScore = score
                bestCol = col
            }
        }

        return bestCol
    }

    func getDropRowAI(board: [[Player?]], col: Int) -> Int? {
        for row in (0..<GameState.rows).reversed() {
            if board[row][col] == nil {
                return row
            }
        }
        return nil
    }

    func minimaxAI(board: inout [[Player?]], depth: Int, alpha: Int, beta: Int, isMaximizing: Bool) -> Int {
        if let winner = checkWinnerAI(board: board) {
            return winner == .yellow ? 10000 + depth : -10000 - depth
        }

        if isBoardFullAI(board: board) { return 0 }
        if depth == 0 { return evaluateBoardAI(board: board) }

        var alpha = alpha
        var beta = beta

        if isMaximizing {
            var maxScore = Int.min
            for col in 0..<GameState.columns {
                guard board[0][col] == nil else { continue }
                let row = getDropRowAI(board: board, col: col)!
                board[row][col] = .yellow
                let score = minimaxAI(board: &board, depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: false)
                board[row][col] = nil
                maxScore = max(maxScore, score)
                alpha = max(alpha, score)
                if beta <= alpha { break }
            }
            return maxScore
        } else {
            var minScore = Int.max
            for col in 0..<GameState.columns {
                guard board[0][col] == nil else { continue }
                let row = getDropRowAI(board: board, col: col)!
                board[row][col] = .red
                let score = minimaxAI(board: &board, depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: true)
                board[row][col] = nil
                minScore = min(minScore, score)
                beta = min(beta, score)
                if beta <= alpha { break }
            }
            return minScore
        }
    }

    func checkWinnerAI(board: [[Player?]]) -> Player? {
        for row in 0..<GameState.rows {
            for col in 0..<GameState.columns {
                if let player = board[row][col], checkWinAI(board: board, row: row, col: col, player: player) {
                    return player
                }
            }
        }
        return nil
    }

    func checkWinAI(board: [[Player?]], row: Int, col: Int, player: Player) -> Bool {
        let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for (dr, dc) in directions {
            var count = 1
            var r = row + dr, c = col + dc
            while r >= 0 && r < GameState.rows && c >= 0 && c < GameState.columns && board[r][c] == player {
                count += 1; r += dr; c += dc
            }
            r = row - dr; c = col - dc
            while r >= 0 && r < GameState.rows && c >= 0 && c < GameState.columns && board[r][c] == player {
                count += 1; r -= dr; c -= dc
            }
            if count >= 4 { return true }
        }
        return false
    }

    func isBoardFullAI(board: [[Player?]]) -> Bool {
        for col in 0..<GameState.columns {
            if board[0][col] == nil { return false }
        }
        return true
    }

    func evaluateBoardAI(board: [[Player?]]) -> Int {
        var score = 0
        let centerCol = GameState.columns / 2
        for row in 0..<GameState.rows {
            if board[row][centerCol] == .yellow { score += 3 }
            else if board[row][centerCol] == .red { score -= 3 }
        }
        score += evaluateWindowsAI(board: board)
        return score
    }

    func evaluateWindowsAI(board: [[Player?]]) -> Int {
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
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        player.lightColor,
                        player.color,
                        player.darkColor
                    ]),
                    center: .init(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: size * 0.55
                )
            )
            .overlay(
                Circle()
                    .strokeBorder(player.darkColor.opacity(0.4), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 1, y: 2)
            .scaleEffect(isWinning ? 1.05 : 1.0)
    }
}

struct SlotView: View {
    let row: Int
    let col: Int
    let player: Player?
    let isWinning: Bool
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

    private let spacing: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - 40
            let availableHeight = geo.size.height - 100
            let slotFromWidth = (availableWidth - spacing * 8) / 7
            let slotFromHeight = (availableHeight - spacing * 7) / 6
            let slotSize = min(slotFromWidth, slotFromHeight, 65)
            let boardWidth = slotSize * 7 + spacing * 8
            let boardHeight = slotSize * 6 + spacing * 7

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
                                    size: slotSize - 8
                                )
                                .opacity(0.7)
                            }
                        }
                        .frame(width: slotSize, height: slotSize)
                    }
                }
                .frame(width: boardWidth - spacing * 2, height: slotSize)
                .padding(.bottom, 4)

                // Game board
                VStack(spacing: spacing) {
                    ForEach(0..<GameState.rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<GameState.columns, id: \.self) { col in
                                let isWinning = gameState.winningCells.contains { $0.row == row && $0.col == col }

                                ZStack {
                                    // Slot hole with inset effect
                                    Circle()
                                        .fill(GameColors.slotBackground(for: colorScheme))
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.black.opacity(0.5),
                                                            Color.white.opacity(0.1)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 2
                                                )
                                        )
                                        .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 2)

                                    // Hover preview (when empty)
                                    if hoveredColumn == col && gameState.board[row][col] == nil {
                                        if let targetRow = gameState.getDropRow(for: col), targetRow == row {
                                            Circle()
                                                .fill(gameState.currentPlayer.color.opacity(0.25))
                                                .padding(4)
                                        }
                                    }

                                    // Game piece
                                    if let player = gameState.board[row][col] {
                                        PieceView(
                                            player: player,
                                            isWinning: isWinning,
                                            size: slotSize - 8
                                        )
                                        .padding(4)
                                        .shadow(color: isWinning ? player.color.opacity(0.8) : Color.clear, radius: isWinning ? 10 : 0)
                                    }
                                }
                                .frame(width: slotSize, height: slotSize)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if gameState.canDrop(in: col) {
                                        gameState.dropPiece(in: col)
                                        soundManager.playDrop()
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
                .padding(spacing)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [GameColors.boardBlueLight, GameColors.boardBlue, GameColors.boardBlueDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
                )
                .frame(width: boardWidth, height: boardHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

struct DifficultyButton: View {
    let difficulty: Difficulty
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: difficulty.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(difficulty.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : GameColors.textColor(for: colorScheme).opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? 
                          LinearGradient(colors: [GameColors.boardBlueLight, GameColors.boardBlue], startPoint: .top, endPoint: .bottom) :
                          LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom))
            )
        }
        .buttonStyle(.plain)
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
        let textColor = GameColors.textColor(for: effectiveColorScheme)
        let bgColors = GameColors.background(for: effectiveColorScheme)

        GeometryReader { geo in
            let isCompact = geo.size.height < 650
            let titleSize: CGFloat = isCompact ? 26 : 34
            let vSpacing: CGFloat = isCompact ? 10 : 16

            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [bgColors.top, bgColors.bottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: vSpacing) {
                    // Top bar
                    HStack {
                        // Sound toggle
                        Button(action: { soundManager.soundEnabled.toggle() }) {
                            Image(systemName: soundManager.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(textColor.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(GameColors.subtleBackground(for: effectiveColorScheme))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(soundManager.soundEnabled ? "Sound On" : "Sound Off")

                        Spacer()

                        // Appearance toggle
                        HStack(spacing: 2) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                Button(action: { appearanceMode = mode }) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(appearanceMode == mode ? .white : textColor.opacity(0.5))
                                        .frame(width: 32, height: 28)
                                        .background(appearanceMode == mode ? GameColors.boardBlue : Color.clear)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .help(mode.rawValue)
                            }
                        }
                        .padding(4)
                        .background(GameColors.subtleBackground(for: effectiveColorScheme))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 4)

                    // Title
                    Text("CONNECT FOUR")
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [textColor, textColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)

                    // Mode selector
                    HStack(spacing: 4) {
                        ForEach(GameMode.allCases, id: \.self) { mode in
                            Button(action: {
                                if gameState.gameMode != mode {
                                    gameState.gameMode = mode
                                    gameState.reset()
                                }
                            }) {
                                Text(mode.rawValue)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(gameState.gameMode == mode ? .white : textColor.opacity(0.6))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule()
                                            .fill(gameState.gameMode == mode ?
                                                  LinearGradient(colors: [GameColors.boardBlueLight, GameColors.boardBlue], startPoint: .top, endPoint: .bottom) :
                                                    LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(GameColors.subtleBackground(for: effectiveColorScheme))
                    .clipShape(Capsule())
                    
                    // Difficulty selector (only show for single player mode)
                    if gameState.gameMode == .onePlayer {
                        HStack(spacing: 4) {
                            ForEach(Difficulty.allCases, id: \.self) { difficulty in
                                DifficultyButton(
                                    difficulty: difficulty,
                                    isSelected: gameState.difficulty == difficulty,
                                    colorScheme: effectiveColorScheme
                                ) {
                                    if gameState.difficulty != difficulty {
                                        gameState.difficulty = difficulty
                                        gameState.reset()
                                    }
                                }
                            }
                        }
                        .padding(4)
                        .background(GameColors.subtleBackground(for: effectiveColorScheme))
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    // Scores with player indicators
                    HStack(spacing: isCompact ? 30 : 50) {
                        PlayerIndicator(
                            player: .red,
                            score: gameState.scores[.red] ?? 0,
                            isActive: gameState.currentPlayer == .red && gameState.gameResult == .ongoing,
                            label: gameState.gameMode == .onePlayer ? "You" : "Red",
                            compact: isCompact,
                            colorScheme: effectiveColorScheme
                        )

                        Text("VS")
                            .font(.system(size: isCompact ? 14 : 18, weight: .bold, design: .rounded))
                            .foregroundColor(textColor.opacity(0.25))

                        PlayerIndicator(
                            player: .yellow,
                            score: gameState.scores[.yellow] ?? 0,
                            isActive: gameState.currentPlayer == .yellow && gameState.gameResult == .ongoing,
                            label: gameState.gameMode == .onePlayer ? "CPU" : "Yellow",
                            compact: isCompact,
                            colorScheme: effectiveColorScheme
                        )
                    }

                    // Board
                    BoardView(gameState: gameState, soundManager: soundManager, colorScheme: effectiveColorScheme)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Status and controls
                    VStack(spacing: isCompact ? 8 : 12) {
                        // Current player / thinking indicator
                        HStack(spacing: 8) {
                            if gameState.isAIThinking {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(textColor)
                                Text("Computer is thinking...")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(textColor.opacity(0.7))
                            } else if gameState.gameResult == .ongoing {
                                Circle()
                                    .fill(gameState.currentPlayer.color)
                                    .frame(width: 14, height: 14)
                                Text("\(gameState.currentPlayer.rawValue)'s Turn")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(textColor.opacity(0.8))
                            }
                        }
                        .frame(height: 24)

                        // New Game button
                        Button(action: { gameState.reset() }) {
                            Text("New Game")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(textColor.opacity(0.8))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .strokeBorder(textColor.opacity(0.25), lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)

                // Game over overlay
                if gameState.gameResult != .ongoing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    GameOverView(result: gameState.gameResult) {
                        gameState.reset()
                    }
                }
            }
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
