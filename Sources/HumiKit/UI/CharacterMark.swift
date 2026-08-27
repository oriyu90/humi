import SwiftUI

/// Hum's one "character moment": a pear dot that breathes at rest and bursts a
/// 4-point coral star when a new session is created. One per window, no more.
struct CharacterMark: View {
    /// Bump this to trigger a burst (e.g. session count).
    var burstTrigger: Int

    @State private var breathing = false
    @State private var bursts: [BurstToken] = []

    var body: some View {
        ZStack {
            Circle()
                .fill(Hum.pear)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Hum.pearDeep.opacity(0.6), lineWidth: 1))
                .scaleEffect(breathing && !Hum.Motion.reduceMotion ? 1.08 : 1.0)
                .animation(
                    Hum.Motion.reduceMotion ? nil :
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: breathing
                )

            ForEach(bursts) { token in
                StarBurst()
                    .id(token.id)
            }
        }
        .frame(width: 22, height: 22)
        .onAppear { breathing = true }
        .onChange(of: burstTrigger) { _, _ in
            guard !Hum.Motion.reduceMotion else { return }
            let token = BurstToken()
            bursts.append(token)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                bursts.removeAll { $0.id == token.id }
            }
        }
        .accessibilityHidden(true)
    }

    struct BurstToken: Identifiable { let id = UUID() }
}

private struct StarBurst: View {
    @State private var animate = false
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Hum.coral)
            .scaleEffect(animate ? 1.4 : 0.1)
            .opacity(animate ? 0 : 1)
            .rotationEffect(.degrees(animate ? 45 : 0))
            .onAppear {
                withAnimation(.easeOut(duration: 0.42)) { animate = true }
            }
    }
}
