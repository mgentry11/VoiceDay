import SwiftUI

/// Location-triggered checkout checklist
/// Shows when user leaves a saved location (gym, work, etc.)
struct CheckoutChecklistView: View {
    let location: LocationService.SavedLocation
    let onComplete: () -> Void
    let onDismiss: () -> Void

    @ObservedObject private var checkoutService = CheckoutChecklistService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @StateObject private var speechService = SpeechService()
    @EnvironmentObject var appState: AppState

    @State private var currentIndex = 0
    @State private var showingAllDone = false
    @State private var showingIntro = true

    private var items: [CheckoutChecklistService.ChecklistItem] {
        checkoutService.getChecklist(for: location.id).filter { $0.isActive }
    }

    private var currentItem: CheckoutChecklistService.ChecklistItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingIntro {
                introView
            } else if showingAllDone {
                allDoneView
            } else if let item = currentItem {
                checkItemView(for: item)
            } else {
                noItemsView
            }
        }
        .background(Color.themeBackground)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                speakIntro()
            }
        }
    }

    // MARK: - Intro View

    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Location icon
            VStack(spacing: 16) {
                Image(systemName: location.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(themeColors.accent)

                Text("Leaving \(location.name)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(themeColors.text)

                Text("Quick checkout before you go?")
                    .font(.title3)
                    .foregroundStyle(themeColors.subtext)

                // Item count
                Text("\(items.count) items")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeColors.secondary)
                    .cornerRadius(12)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                Button {
                    showingIntro = false
                    speakCurrentItem()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Start Checkout")
                    }
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(themeColors.accent)
                    .cornerRadius(16)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Skip for now")
                        .font(.body)
                        .foregroundStyle(themeColors.subtext)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Check Item View

    private func checkItemView(for item: CheckoutChecklistService.ChecklistItem) -> some View {
        VStack(spacing: 0) {
            // Header with progress
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(themeColors.subtext.opacity(0.5))
                }

                Spacer()

                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(0..<items.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentIndex ? themeColors.accent : themeColors.subtext.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                Text("\(currentIndex + 1)/\(items.count)")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }
            .padding()

            Spacer()

            // Main item display
            VStack(spacing: 24) {
                // Item icon - different for app links
                if item.isExternalAppLink {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(themeColors.accent)
                } else {
                    Text("\(currentIndex + 1)")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColors.accent)
                }

                Text(item.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // App link button
                if item.isExternalAppLink {
                    Button {
                        checkoutService.openAppLink(for: item)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open App")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(themeColors.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(themeColors.accent.opacity(0.15))
                        .cornerRadius(10)
                    }
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 16) {
                // Done button
                Button {
                    markDone()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                            .fontWeight(.bold)
                        Text("Done")
                    }
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.green)
                    .cornerRadius(16)
                }

                // Skip button
                Button {
                    skip()
                } label: {
                    Text("Skip")
                        .font(.body)
                        .foregroundStyle(themeColors.subtext)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - All Done View

    private var allDoneView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.green)

                Text("All Done!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(themeColors.text)

                Text("Checked out from \(location.name)")
                    .font(.title3)
                    .foregroundStyle(themeColors.subtext)

                // Completion stats
                let progress = checkoutService.currentCheckoutProgress
                Text("\(progress.completed)/\(progress.total) completed")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeColors.secondary)
                    .cornerRadius(12)
            }

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("Continue")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(themeColors.accent)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - No Items View

    private var noItemsView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checklist")
                    .font(.system(size: 60))
                    .foregroundStyle(themeColors.subtext.opacity(0.5))

                Text("No checklist items")
                    .font(.title2)
                    .foregroundStyle(themeColors.subtext)

                Text("Add items in Settings > Locations")
                    .font(.subheadline)
                    .foregroundStyle(themeColors.subtext.opacity(0.7))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Text("Got it")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeColors.accent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func markDone() {
        guard let item = currentItem else { return }
        checkoutService.markCompleted(itemId: item.id)
        proceedToNext()
    }

    private func skip() {
        proceedToNext()
    }

    private func proceedToNext() {
        if currentIndex < items.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
            speakCurrentItem()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingAllDone = true
            }
            speakAllDone()
        }
    }

    // MARK: - Speech

    private func speakIntro() {
        let message = getPersonalityIntro()
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage(message)
        }
    }

    private func speakCurrentItem() {
        guard let item = currentItem else { return }
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage(item.title)
        }
    }

    private func speakAllDone() {
        let message = getPersonalityCompletion()
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage(message)
        }
    }

    // MARK: - Personality Messages

    private func getPersonalityIntro() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Leaving \(location.name), I see. Let's do a quick checkout, shall we?"
        case .sergent:
            return "CHECKOUT TIME! Don't leave \(location.name) without completing your checklist, soldier!"
        case .cheerleader:
            return "Yay! Leaving \(location.name)! Quick checklist time - you've got this!"
        case .butler:
            return "If I may, before departing \(location.name), perhaps a brief review of your checklist?"
        case .coach:
            return "Great session at \(location.name)! Let's run through the post-game checklist!"
        case .zen:
            return "As you depart \(location.name), let us mindfully complete your departure ritual."
        case .parent:
            return "Leaving \(location.name), sweetie. Let's make sure you've got everything!"
        case .bestie:
            return "Leaving \(location.name)! Quick checklist before we bounce?"
        case .robot:
            return "Location exit detected: \(location.name). Initiating checkout protocol."
        case .therapist:
            return "Before you leave \(location.name), let's do a gentle check-in."
        case .hypeFriend:
            return "LEAVING \(location.name.uppercased())! CHECKOUT TIME! LET'S GO!"
        case .chillBuddy:
            return "Heading out from \(location.name)... Quick checklist, no rush."
        case .snarky:
            return "Oh, leaving \(location.name) already? Fine, let's do your little checklist."
        case .gamer:
            return "Exiting \(location.name) dungeon! Don't forget to loot your checklist!"
        case .tiredParent:
            return "Leaving \(location.name)... let's do the checklist. I'm tired, you're tired, let's go."
        case .sage:
            return "As you depart \(location.name), the wise complete their rituals."
        case .rebel:
            return "Leaving \(location.name). Don't let chaos follow - do your checklist."
        case .trickster:
            return "Leaving \(location.name)... or ARE you? Quick checklist first."
        case .stoic:
            return "Departing \(location.name). Complete your duties before leaving."
        case .pirate:
            return "Weighing anchor from \(location.name)! All hands for checkout!"
        case .witch:
            return "The departure spell requires your checklist, darling. Let's begin."
        }
    }

    private func getPersonalityCompletion() -> String {
        let personality = appState.selectedPersonality

        switch personality {
        case .pemberton:
            return "Checkout complete. Well done. Now off you go."
        case .sergent:
            return "CHECKOUT COMPLETE! Move out, soldier!"
        case .cheerleader:
            return "Amazing! You're all checked out! Have a great rest of your day!"
        case .butler:
            return "Checkout complete, if I may say so. Safe travels."
        case .coach:
            return "Great checkout! Now get some rest and come back stronger!"
        case .zen:
            return "Your departure is complete. Go in peace."
        case .parent:
            return "All checked out, sweetie. Be safe!"
        case .bestie:
            return "Done and done! See ya later!"
        case .robot:
            return "Checkout protocol complete. Departure authorized."
        case .therapist:
            return "Wonderful. You've completed your checklist. Take care of yourself."
        case .hypeFriend:
            return "YOU DID IT! CHECKOUT CHAMPION! GO BE AMAZING!"
        case .chillBuddy:
            return "Nice, all done. Later."
        case .snarky:
            return "Wow, you actually finished. I'm impressed. Sort of."
        case .gamer:
            return "Quest complete! +50 XP for checkout mastery!"
        case .tiredParent:
            return "Done. Great. Now we can both rest. Or not. Probably not."
        case .sage:
            return "The checkout ritual is complete. Go forth with wisdom."
        case .rebel:
            return "Checklist done. Now go change the world."
        case .trickster:
            return "Checkout complete! Unless... no, it's definitely complete. Probably."
        case .stoic:
            return "Duty fulfilled. Depart with clear conscience."
        case .pirate:
            return "All cargo accounted for! Set sail, matey!"
        case .witch:
            return "The departure spell is complete. Safe travels, darling."
        }
    }
}

// MARK: - Preview

#Preview {
    CheckoutChecklistView(
        location: LocationService.SavedLocation(
            name: "Gym",
            latitude: 0,
            longitude: 0,
            icon: "dumbbell.fill"
        ),
        onComplete: {},
        onDismiss: {}
    )
    .environmentObject(AppState())
}
