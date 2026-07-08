import SwiftUI

/// The chat popup UI: a scrollable transcript plus a text field, bound to a
/// ClaudeChatSession. Kept intentionally small/borderless-window-friendly —
/// no navigation bars, no window chrome assumptions.
struct ChatView: View {
    @ObservedObject var session: ClaudeChatSession
    var onClose: () -> Void
    @State private var draft: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            Divider()
            composer
        }
        .frame(width: 300, height: 380)
        .background(.regularMaterial)
        .onAppear { fieldFocused = true }
    }

    private var header: some View {
        HStack {
            Text("Your buddy")
                .font(.subheadline.bold())
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if session.messages.isEmpty {
                        Text("Say something. He's got jokes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                    }
                    ForEach(session.messages) { message in
                        bubble(for: message)
                            .id(message.id)
                    }
                    if session.isThinking {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding(10)
            }
            .onChange(of: session.messages) { _ in scrollToEnd(proxy) }
            .onChange(of: session.isThinking) { _ in scrollToEnd(proxy) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation {
            if session.isThinking {
                proxy.scrollTo("typing", anchor: .bottom)
            } else {
                proxy.scrollTo(session.messages.last?.id, anchor: .bottom)
            }
        }
    }

    private func bubble(for message: ChatMessage) -> some View {
        HStack {
            if message.role == .assistant { Spacer(minLength: 30) }
            Text(message.text)
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(message.role == .user ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if message.role == .user { Spacer(minLength: 30) }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var typingIndicator: some View {
        HStack {
            Text("...")
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 30)
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Talk to him...", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($fieldFocused)
                .onSubmit(sendDraft)
            Button(action: sendDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
    }

    private func sendDraft() {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        draft = ""
        Task { await session.send(text) }
    }
}
