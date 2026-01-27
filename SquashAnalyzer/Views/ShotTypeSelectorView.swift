import SwiftUI

/// View for selecting the type of shot after zone selection
struct ShotTypeSelectorView: View {
    let game: Game
    let onShotSelected: (ShotType) -> Void
    let onBack: () -> Void

    private var playerColor: Color {
        game.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with context
            headerSection

            // Shot type grid
            shotTypeGrid

            // Back button
            backButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.backgroundMedium.opacity(0.95))
                .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(playerColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 6) {
            if let player = game.selectedPlayer, let zone = game.selectedZone {
                Text("\(game.name(for: player).uppercased()) SCOORT")
                    .font(AppFonts.caption(11))
                    .foregroundColor(playerColor)
                    .tracking(1.5)

                Text("in \(zone.rawValue)")
                    .font(AppFonts.body(14))
                    .foregroundColor(AppColors.textSecondary)
            }

            Text("Welke slag?")
                .font(AppFonts.title(18))
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 4)
        }
    }

    // MARK: - Shot Type Grid
    private var shotTypeGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(ShotType.allCases) { shotType in
                ShotTypeButton(
                    shotType: shotType,
                    color: playerColor
                ) {
                    onShotSelected(shotType)
                }
            }
        }
    }

    // MARK: - Back Button
    private var backButton: some View {
        Button(action: onBack) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("Terug")
                    .font(AppFonts.caption(12))
            }
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}

// MARK: - Shot Type Button
struct ShotTypeButton: View {
    let shotType: ShotType
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon
                Image(systemName: shotType.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isPressed ? color : AppColors.textPrimary)

                // Name
                Text(shotType.rawValue.uppercased())
                    .font(AppFonts.caption(10))
                    .foregroundColor(isPressed ? color : AppColors.textSecondary)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPressed ? color.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPressed ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview

#Preview("Shot Type Selector - Player 1") {
    ZStack {
        AppBackground()

        let game = Game()
        let _ = {
            game.player1Name = "Niels"
            game.player2Name = "Paul"
            game.selectPlayer(.player1)
            game.selectZone(.frontLeft)
        }()

        ShotTypeSelectorView(
            game: game,
            onShotSelected: { shot in print("Selected: \(shot)") },
            onBack: { print("Back") }
        )
    }
}

#Preview("Shot Type Selector - Player 2") {
    ZStack {
        AppBackground()

        let game = Game()
        let _ = {
            game.player1Name = "Niels"
            game.player2Name = "Paul"
            game.selectPlayer(.player2)
            game.selectZone(.backRight)
        }()

        ShotTypeSelectorView(
            game: game,
            onShotSelected: { shot in print("Selected: \(shot)") },
            onBack: { print("Back") }
        )
    }
}
