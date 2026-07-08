import SwiftUI

/// Classic comic speech-bubble outline: rounded body + a small triangular
/// tail pointing down toward the character. Pure Path — no image assets.
private struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 14
    var tailWidth: CGFloat = 16
    var tailHeight: CGFloat = 11
    /// 0 = tail at bubble's left edge, 1 = right edge. Kept slightly left of
    /// center so it reads as pointing at the character's head, not its feet.
    var tailPosition: CGFloat = 0.32

    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
        var path = Path(roundedRect: bodyRect, cornerRadius: cornerRadius)

        let tailCenterX = bodyRect.minX + bodyRect.width * tailPosition
        path.move(to: CGPoint(x: tailCenterX - tailWidth / 2, y: bodyRect.maxY - 1))
        path.addLine(to: CGPoint(x: tailCenterX, y: rect.maxY))
        path.addLine(to: CGPoint(x: tailCenterX + tailWidth / 2, y: bodyRect.maxY - 1))
        path.closeSubpath()

        return path
    }
}

/// The bubble itself: white fill, black stroke, bold text. Sizes to its text.
private struct DeadpoolSpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, 9 + 11)
            .frame(maxWidth: 188)
            .fixedSize(horizontal: false, vertical: true)
            .background(SpeechBubbleShape().fill(.white))
            .overlay(SpeechBubbleShape().stroke(Color.black, lineWidth: 1.6))
    }
}

/// Pop-in/pop-out wrapper: shows `text` with a spring scale+fade, holds it,
/// then the owning controller clears `text` after ~6s to dismiss. Never
/// intercepts clicks so it can sit right on top of the character's tap/drag
/// target.
struct DeadpoolBubbleOverlay: View {
    let text: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let text {
                DeadpoolSpeechBubble(text: text)
                    .transition(
                        .scale(scale: 0.1, anchor: .bottom)
                        .combined(with: .opacity)
                    )
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.32, dampingFraction: 0.55), value: text)
    }
}
