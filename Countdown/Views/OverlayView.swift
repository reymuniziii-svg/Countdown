import SwiftUI

struct OverlayView: View {
    let event: MeetingEvent
    @ObservedObject var monitor: MeetingMonitor
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    let onJoin: () -> Void

    @State private var appeared = false
    @State private var numberScale: CGFloat = 1.0
    @State private var lastSeconds: Int = -1

    var body: some View {
        ZStack {
            // Dark translucent background
            Color.black.opacity(0.85)

            VStack(spacing: 24) {
                Spacer()

                // Hero countdown number
                Text(countdownText)
                    .font(.system(size: 160, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .scaleEffect(numberScale)
                    .animation(.easeOut(duration: 0.15), value: numberScale)
                    .onChange(of: monitor.countdownSeconds) { newValue in
                        // Pulse on each tick
                        if newValue != lastSeconds {
                            lastSeconds = newValue
                            numberScale = 1.08
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                numberScale = 1.0
                            }
                        }
                    }

                // Meeting title
                Text(event.title)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)

                // Start time
                Text(event.formattedStartTime)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                // Action buttons
                HStack(spacing: 16) {
                    if event.videoLink != nil {
                        Button(action: onJoin) {
                            Label("Join \(serviceName)", systemImage: "video.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                    }

                    Button(action: onSnooze) {
                        Text("Snooze 1 min")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.15))
                            .foregroundStyle(.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.1))
                            .foregroundStyle(.white.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea()
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
        }
    }

    private var countdownText: String {
        let s = monitor.countdownSeconds
        if s <= 0 {
            return "GO"
        }
        return "\(s)"
    }

    private var serviceName: String {
        if let url = event.videoLink {
            return VideoLinkDetector.serviceName(for: url)
        }
        return "Meeting"
    }
}
