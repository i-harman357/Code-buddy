import SwiftUI

/// Chibi wisecracker: big round red head (mask look via black oval eyes with
/// white highlights), tiny red-and-black body, one arm raised in a "talking"
/// pose. Built entirely from SwiftUI shape primitives — no image assets, no
/// copyrighted artwork. An ORIGINAL character design "inspired by" that
/// energy, not a reproduction of any specific costume.
struct DeadpoolCharacterView: View {
    @ObservedObject var model: DockCharacterModel
    /// Only used by the roaming desktop-pet window; the small Dock-tile
    /// usage leaves these at their defaults.
    var facingRight: Bool = true
    var isWalking: Bool = false

    private let red = Color(red: 0xD4 / 255, green: 0x2B / 255, blue: 0x2B / 255)
    private let black = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255)

    private var pulse: Double { (sin(model.animPhase * 0.3) + 1) / 2 }

    /// Eyes narrow to sleepy slits while away.
    private var eyeHeightFactor: CGFloat {
        model.state == .away ? 0.08 : 0.30
    }

    /// Slow idle bob in FLOW, a little more energy in ACTIVE.
    private var bodyBob: CGFloat {
        switch model.state {
        case .flow: return CGFloat(sin(model.animPhase * 0.12)) * 0.01
        case .active: return CGFloat(sin(model.animPhase * 0.35)) * 0.015
        default: return 0
        }
    }

    /// Side-to-side jitter while STALLING — visibly more "worked up" than
    /// any other state.
    private var jitterX: CGFloat {
        model.state == .stalling ? CGFloat(sin(model.animPhase * 1.4)) * 0.02 : 0
    }

    /// Head droops while away.
    private var headTilt: Double {
        model.state == .away ? 10 : 0
    }

    /// Raised "talking" arm: a fixed raised angle, plus a little wave while
    /// ACTIVE/STALLING so it reads as mid-commentary.
    private var armAngle: Double {
        let base = -50.0
        switch model.state {
        case .active: return base + sin(model.animPhase * 0.4) * 10
        case .stalling: return base + sin(model.animPhase * 1.2) * 16
        default: return base
        }
    }

    private var zProgress: Double {
        model.animPhase.truncatingRemainder(dividingBy: 22) / 22
    }

    /// Little footstep bounce while the desktop pet is actually walking;
    /// stays at 0 for the static Dock-tile usage.
    private var walkBob: CGFloat {
        isWalking ? CGFloat(sin(model.animPhase * 0.9)) * 0.03 : 0
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let headD = h * 0.56
            let torsoW = headD * 0.6
            let torsoH = h * 0.20
            let legW = torsoW * 0.32
            let legH = h * 0.095
            let bootH = h * 0.045

            VStack(spacing: h * 0.012) {
                head(diameter: headD)

                ZStack(alignment: .top) {
                    VStack(spacing: h * 0.006) {
                        torso(width: torsoW, height: torsoH)
                        HStack(spacing: torsoW * 0.2) {
                            legAndBoot(legWidth: legW, legHeight: legH, bootHeight: bootH)
                            legAndBoot(legWidth: legW, legHeight: legH, bootHeight: bootH)
                        }
                    }

                    raisedArm(length: headD * 0.58, width: headD * 0.17)
                        .offset(x: torsoW * 0.62, y: -torsoH * 0.02)
                }
            }
            .offset(x: jitterX * h, y: (bodyBob + walkBob) * h)
            .scaleEffect(x: facingRight ? 1 : -1, y: 1)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)

            if model.state == .stalling {
                Image(systemName: "exclamationmark")
                    .font(.system(size: h * 0.11, weight: .bold))
                    .foregroundStyle(black)
                    .opacity(pulse)
                    .position(x: geo.size.width * 0.82, y: h * 0.14)
            }

            if model.state == .away {
                Text("z")
                    .font(.system(size: h * 0.13, weight: .bold, design: .rounded))
                    .foregroundStyle(black.opacity(0.6 * (1 - zProgress)))
                    .position(x: geo.size.width * 0.8, y: h * (0.18 - 0.14 * zProgress))
            }
        }
    }

    // MARK: - Head

    private func head(diameter d: CGFloat) -> some View {
        ZStack {
            Circle().fill(red).frame(width: d, height: d)
            Circle().stroke(black, lineWidth: max(d * 0.035, 1.5)).frame(width: d, height: d)

            HStack(spacing: d * 0.14) {
                eye(headDiameter: d)
                eye(headDiameter: d)
            }
            .offset(y: -d * 0.02)
        }
        .rotationEffect(.degrees(headTilt))
    }

    private func eye(headDiameter d: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Ellipse()
                .fill(black)
                .frame(width: d * 0.22, height: d * eyeHeightFactor)
            Circle()
                .fill(.white)
                .frame(width: d * 0.045, height: d * 0.045)
                .offset(x: d * 0.03, y: d * eyeHeightFactor * 0.18)
        }
    }

    // MARK: - Body

    private func torso(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: w * 0.32, style: .continuous)
                .fill(red)
                .frame(width: w, height: h)
            RoundedRectangle(cornerRadius: w * 0.32, style: .continuous)
                .stroke(black, lineWidth: max(w * 0.06, 1.5))
                .frame(width: w, height: h)

            RoundedRectangle(cornerRadius: w * 0.08, style: .continuous)
                .fill(black)
                .frame(width: w * 1.04, height: h * 0.18)
                .offset(y: h * 0.56)
        }
    }

    private func legAndBoot(legWidth: CGFloat, legHeight: CGFloat, bootHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: legWidth * 0.3, style: .continuous)
                .fill(red)
                .overlay(
                    RoundedRectangle(cornerRadius: legWidth * 0.3, style: .continuous)
                        .stroke(black, lineWidth: max(legWidth * 0.14, 1))
                )
                .frame(width: legWidth, height: legHeight)

            RoundedRectangle(cornerRadius: legWidth * 0.35, style: .continuous)
                .fill(black)
                .frame(width: legWidth * 1.2, height: bootHeight)
        }
    }

    private func raisedArm(length: CGFloat, width: CGFloat) -> some View {
        Capsule()
            .fill(red)
            .overlay(Capsule().stroke(black, lineWidth: max(width * 0.16, 1.2)))
            .frame(width: width, height: length)
            .rotationEffect(.degrees(armAngle), anchor: .bottom)
    }
}
