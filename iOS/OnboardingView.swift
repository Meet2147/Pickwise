import SwiftUI

/// Three-page first-launch onboarding. Shown once (@AppStorage flag in MobileRootView).
struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack {
            Neu.bg.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer(minLength: 20)
                TabView(selection: $page) {
                    OnboardPage(icon: { AnyView(
                        Image("OnboardLogo")
                            .resizable().scaledToFit()
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    )},
                        title: "Which one should I buy?",
                        text: "Pickwise compares any 2–5 products — headphones, laptops, anything — and answers with one verdict, not a shortlist.")
                        .tag(0)
                    OnboardPage(icon: { AnyView(
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(Neu.accent)
                            .frame(width: 110, height: 110)
                            .neuInset(radius: 55)
                    )},
                        title: "Real research, today's prices",
                        text: "Type names, paste links or specs, or attach a photo of the product. Pickwise reads the web live and cites its sources.")
                        .tag(1)
                    OnboardPage(icon: { AnyView(
                        Text("3")
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(Neu.accent)
                            .frame(width: 110, height: 110)
                            .neuInset(radius: 55)
                    )},
                        title: "Three on the house",
                        text: "Your first three comparisons are free — no account, nothing to set up. Each one takes about a minute of live research.")
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(i == page ? Neu.accent : Neu.ink2.opacity(0.35))
                            .frame(width: 8, height: 8)
                    }
                }

                Button(page == 2 ? "Get started" : "Continue") {
                    if page == 2 { onDone() }
                    else { withAnimation { page += 1 } }
                }
                .buttonStyle(NeuButtonStyle(prominent: true))
                .padding(.bottom, 8)

                if page < 2 {
                    Button("Skip") { onDone() }
                        .font(Neu.Font.caption).foregroundStyle(Neu.ink2)
                        .buttonStyle(.plain)
                        .padding(.bottom, 12)
                } else {
                    Color.clear.frame(height: 27).padding(.bottom, 12)
                }
            }
            .padding(24)
        }
        .task {
            guard SampleData.isDemo else { return }
            for _ in 0..<3 {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                if page < 2 { withAnimation { page += 1 } } else { onDone(); break }
            }
        }
    }
}

private struct OnboardPage: View {
    let icon: () -> AnyView
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 26) {
            icon()
            Text(title).font(Neu.Font.hero).foregroundStyle(Neu.ink)
                .multilineTextAlignment(.center)
            Text(text).font(Neu.Font.body).foregroundStyle(Neu.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .padding(.top, 30)
    }
}
