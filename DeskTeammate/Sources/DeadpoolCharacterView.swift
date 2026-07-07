import SwiftUI

/// Masked wisecracker: black rounded head, white almond eyes, a thin accent
/// "smirk" line that tilts with state. Built entirely from shape primitives —
/// same minimal, no-image-assets visual language as DockCharacterView and
/// BuddyCharacterView. This is a generic masked-character abstraction (no
/// logos, no costume details, no copyrighted artwork) representing the
/// sarcastic "wisecrack" personality the Claude delegate uses for nudges.
struct DeadpoolCharacterView: View {
    @ObservedObject var model: DockCharacterModel

    private var accent: Color {
        switch model.state {
        case .stopped: return .gray
        case .flow: return .red.opacity(0.6)
        case .active: return .red
        case .stalling: return .orange
        case .away: return .gray
        }
    }

    private var pulse: Double { (sin(model.animPhase * 0.3) + 1) / 2 }

    private var eyeSquint: CGFloat {
        model.state == .away ? 0.1 : 0.34
    }

    /// Smirk tilts more while stalling (sass), slight steady tilt while active.
    private var smirkTilt: Double {
        switch model.state {
        case .stalling: return sin(model.animPhase * 0.7) * 10
        case .active: return 6
        default: return 0
        }
    }

    private var zProgress: Double {
        model.animPhase.truncatingRemainder(dividingBy: 22) / 22
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)

            ZStack {
                RoundedRectangle(cornerRadius: s * 0.26, style: .continuous)
                    .fill(Color.black)
                    .frame(width: s * 0.72, height: s * 0.78)

                RoundedRectangle(cornerRadius: s * 0.26, style: .continuous)
                    .strokeBorder(accent.opacity(0.9), lineWidth: max(s * 0.025, 1.5))
                    .frame(width: s * 0.72, height: s * 0.78)

                HStack(spacing: s * 0.1) {
                    almondEye(size: s)
                    almondEye(size: s)
                }
                .offset(y: -s * 0.12)

                Capsule()
                    .fill(accent)
                    .frame(width: s * 0.26, height: max(s * 0.03, 1.5))
                    .rotationEffect(.degrees(smirkTilt))
                    .offset(y: s * 0.14)

                if model.state == .stalling {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: s * 0.14, weight: .bold))
                        .foregroundStyle(accent)
                        .opacity(pulse)
                        .offset(x: s * 0.26, y: -s * 0.3)
                }

                if model.state == .away {
                    Text("z")
                        .font(.system(size: s * 0.16, weight: .bold, design: .rounded))
                        .foregroundStyle(accent.opacity(0.7 * (1 - zProgress)))
                        .offset(x: s * 0.24, y: -s * 0.26 - s * 0.18 * zProgress)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func almondEye(size s: CGFloat) -> some View {
        Capsule()
            .fill(Color.white)
            .frame(width: s * 0.12, height: s * eyeSquint)
            .rotationEffect(.degrees(-8))
    }
}
