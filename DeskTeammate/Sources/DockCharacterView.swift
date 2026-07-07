import SwiftUI

/// Switches between the available Dock characters based on the model's kind.
struct DockCharacterContainerView: View {
    @ObservedObject var model: DockCharacterModel

    var body: some View {
        switch model.kind {
        case .robot: DockCharacterView(model: model)
        case .buddy: BuddyCharacterView(model: model)
        case .deadpool: DeadpoolCharacterView(model: model)
        }
    }
}

/// Minimal robot-helmet character: visor frame, two eyes, arc-reactor chest light.
/// Color + motion communicate state; no image assets.
struct DockCharacterView: View {
    @ObservedObject var model: DockCharacterModel

    private var color: Color {
        switch model.state {
        case .stopped: return .gray
        case .flow: return .green
        case .active: return .blue
        case .stalling: return .orange
        case .away: return .gray
        }
    }

    /// 0...1 breathing/pulse value. Ticks faster in high-energy states, so this
    /// naturally oscillates faster there even though the formula is identical.
    private var pulse: Double {
        (sin(model.animPhase * 0.3) + 1) / 2
    }

    private var reactorOpacity: Double {
        switch model.state {
        case .away: return 0.15 + pulse * 0.05
        case .stopped: return 0.25
        default: return 0.5 + pulse * 0.5
        }
    }

    private var eyeHeightFactor: CGFloat {
        model.state == .away ? 0.12 : 0.32
    }

    private var waveOffsetFactor: CGFloat {
        model.state == .stalling ? CGFloat(sin(model.animPhase * 0.8)) * 0.08 : 0
    }

    private var zProgress: Double {
        model.animPhase.truncatingRemainder(dividingBy: 20) / 20
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)

            ZStack {
                RoundedRectangle(cornerRadius: s * 0.24, style: .continuous)
                    .fill(Color.black)
                    .frame(width: s * 0.72, height: s * 0.72)

                RoundedRectangle(cornerRadius: s * 0.24, style: .continuous)
                    .strokeBorder(color.opacity(0.85), lineWidth: max(s * 0.025, 1.5))
                    .frame(width: s * 0.72, height: s * 0.72)

                HStack(spacing: s * 0.11) {
                    Capsule().fill(color).frame(width: s * 0.11, height: s * eyeHeightFactor)
                    Capsule().fill(color).frame(width: s * 0.11, height: s * eyeHeightFactor)
                }
                .offset(y: -s * 0.09)
                .offset(x: s * waveOffsetFactor)

                Circle()
                    .fill(color)
                    .opacity(reactorOpacity)
                    .frame(width: s * 0.16, height: s * 0.16)
                    .offset(y: s * 0.2)
                Circle()
                    .stroke(color, lineWidth: max(s * 0.016, 1))
                    .frame(width: s * 0.22, height: s * 0.22)
                    .offset(y: s * 0.2)

                if model.state == .stalling {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: s * 0.14, weight: .bold))
                        .foregroundStyle(color)
                        .opacity(pulse)
                        .offset(x: s * 0.26, y: -s * 0.28)
                }

                if model.state == .away {
                    Image(systemName: "zzz")
                        .font(.system(size: s * 0.16, weight: .bold))
                        .foregroundStyle(color.opacity(0.7 * (1 - zProgress)))
                        .offset(x: s * 0.22, y: -s * 0.24 - s * 0.18 * zProgress)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
