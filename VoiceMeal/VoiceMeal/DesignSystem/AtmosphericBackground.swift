import SwiftUI

/// Layered atmospheric background — base gradient + decorative orange/purple radial halos.
/// Apply to main tab views (HomeView, PlanView, StatisticsView, SettingsView).
struct AtmosphericBackground: View {
    var body: some View {
        ZStack {
            Theme.backgroundGradient
                .ignoresSafeArea()

            // Top-right warm orange halo — distant sunset
            RadialGradient(
                colors: [
                    Theme.indioOrange.opacity(0.18),
                    Theme.indioOrange.opacity(0.0)
                ],
                center: UnitPoint(x: 0.85, y: 0.05),
                startRadius: 30,
                endRadius: 280
            )
            .blur(radius: 40)
            .ignoresSafeArea()

            // Bottom-left purple haze — Indio brand family
            RadialGradient(
                colors: [
                    Theme.atmospherePurple.opacity(0.22),
                    Theme.atmospherePurple.opacity(0.0)
                ],
                center: UnitPoint(x: 0.10, y: 0.88),
                startRadius: 20,
                endRadius: 260
            )
            .blur(radius: 50)
            .ignoresSafeArea()

            // Mid-screen faint orange depth layer
            RadialGradient(
                colors: [
                    Theme.indioOrange.opacity(0.08),
                    Theme.indioOrange.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadius: 0,
                endRadius: 200
            )
            .blur(radius: 60)
            .ignoresSafeArea()
        }
    }
}
