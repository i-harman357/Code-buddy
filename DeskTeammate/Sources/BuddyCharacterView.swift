import SwiftUI

/// Two flat, geometric figures (tall + short) — no SF Symbols, no image assets.
/// Built entirely from SwiftUI shape primitives (circle/capsule are Path-backed).
struct BuddyCharacterView: View {
    @ObservedObject var model: DockCharacterModel

    private var color: Color {
        switch model.state {
        case .stopped: return .gray
        case .flow: return .mint
        case .active: return .blue
        case .stalling: return .orange
        case .away: return .indigo
        }
    }

    /// Slow idle sway while calm.
    private var sway: Double {
        model.state == .flow ? sin(model.animPhase * 0.15) * 3 : 0
    }

    /// Gentle bounce-in-place while active.
    private var bounce: Double {
        model.state == .active ? abs(sin(model.animPhase * 0.5)) : 0
    }

    /// Short one "looks around" while stalling.
    private var lookAngle: Double {
        model.state == .stalling ? sin(model.animPhase * 0.6) * 14 : 0
    }

    /// Tall one nudges toward short one while stalling.
    private var nudgeShift: Double {
        model.state == .stalling ? (sin(model.animPhase * 0.4) + 1) / 2 * 3 : 0
    }

    private var sitting: Bool { model.state == .away }

    private var zProgress: Double {
        model.animPhase.truncatingRemainder(dividingBy: 24) / 24
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)

            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: s * 0.07) {
                    BuddyFigure(height: s * 0.52, headTilt: 0, color: color, sitting: sitting)
                        .offset(x: -s * (nudgeShift / 100), y: -s * bounce * 0.05)
                    BuddyFigure(height: s * 0.36, headTilt: lookAngle, color: color, sitting: sitting)
                        .offset(x: s * (nudgeShift / 100), y: -s * bounce * 0.035)
                }
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .offset(y: -s * 0.06)

                if model.state == .away {
                    Text("z")
                        .font(.system(size: s * 0.14, weight: .bold, design: .rounded))
                        .foregroundStyle(color.opacity(0.7 * (1 - zProgress)))
                        .offset(x: s * 0.3, y: -s * 0.58 - s * 0.16 * zProgress)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }
}

private struct BuddyFigure: View {
    let height: CGFloat
    let headTilt: Double
    let color: Color
    let sitting: Bool

    var body: some View {
        VStack(spacing: height * 0.05) {
            Circle()
                .fill(color)
                .frame(width: height * 0.44, height: height * 0.44)
                .rotationEffect(.degrees(headTilt))

            Capsule()
                .fill(color.opacity(0.85))
                .frame(width: height * 0.5, height: sitting ? height * 0.3 : height * 0.6)
        }
    }
}
