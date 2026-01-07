import SwiftUI

struct CheckInQuickSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dayStructure = DayStructureService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    checkInCard(
                        title: "Morning",
                        subtitle: "Start your day right",
                        icon: "sunrise.fill",
                        color: .orange,
                        isEnabled: $dayStructure.morningCheckInEnabled,
                        time: $dayStructure.morningCheckInTime
                    )
                    
                    checkInCard(
                        title: "Afternoon",
                        subtitle: "Midday focus reset",
                        icon: "sun.max.fill",
                        color: .yellow,
                        isEnabled: $dayStructure.middayCheckInEnabled,
                        time: $dayStructure.middayCheckInTime
                    )
                    
                    checkInCard(
                        title: "Evening",
                        subtitle: "Wind down & reflect",
                        icon: "moon.fill",
                        color: .indigo,
                        isEnabled: $dayStructure.bedtimeCheckInEnabled,
                        time: $dayStructure.bedtimeCheckInTime
                    )
                    
                    customCheckInSection
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(themeColors.background.ignoresSafeArea())
            .navigationTitle("Daily Check-ins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 44))
                .foregroundStyle(themeColors.accent)
            
            Text("Set Your Check-in Times")
                .font(.title2.bold())
                .foregroundStyle(themeColors.text)
            
            Text("I'll remind you at these times each day")
                .font(.subheadline)
                .foregroundStyle(themeColors.subtext)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    private func checkInCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        isEnabled: Binding<Bool>,
        time: Binding<Date>
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(themeColors.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }
                
                Spacer()
                
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .tint(color)
            }
            .padding()
            
            if isEnabled.wrappedValue {
                Divider()
                    .padding(.horizontal)
                
                HStack {
                    Text("Time")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                    
                    Spacer()
                    
                    DatePicker(
                        "",
                        selection: time,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(color)
                }
                .padding()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isEnabled.wrappedValue ? color.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
    
    private var customCheckInSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Custom Check-in")
                    .font(.headline)
                    .foregroundStyle(themeColors.text)
                Spacer()
            }
            
            if dayStructure.customCheckIns.isEmpty {
                Button {
                    addSampleCustomCheckIn()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.teal)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Custom Check-in")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(themeColors.text)
                            Text("Create your own routine")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundStyle(themeColors.subtext)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeColors.secondary.opacity(0.5))
                    )
                }
            } else {
                ForEach(dayStructure.customCheckIns) { checkIn in
                    customCheckInRow(checkIn)
                }
                
                Button {
                    addSampleCustomCheckIn()
                } label: {
                    Label("Add Another", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private func customCheckInRow(_ checkIn: DayStructureService.CustomCheckIn) -> some View {
        HStack(spacing: 16) {
            Image(systemName: checkIn.icon)
                .font(.title2)
                .foregroundStyle(checkIn.color)
                .frame(width: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(checkIn.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(themeColors.text)
                Text(formatTime(checkIn.time))
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { checkIn.isEnabled },
                set: { _ in dayStructure.toggleCustomCheckIn(id: checkIn.id) }
            ))
            .labelsHidden()
            .tint(.teal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary.opacity(0.5))
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func addSampleCustomCheckIn() {
        _ = dayStructure.addCustomCheckIn(
            name: "Focus Break",
            subtitle: "Quick stretch and water",
            icon: "figure.walk",
            colorHex: "#14B8A6",
            time: DayStructureService.defaultTime(hour: 15, minute: 0),
            items: [
                DayStructureService.CheckInItem(title: "Stretch for 2 minutes", icon: "figure.flexibility"),
                DayStructureService.CheckInItem(title: "Get water", icon: "drop.fill"),
                DayStructureService.CheckInItem(title: "Check posture", icon: "person.fill")
            ]
        )
    }
}

#Preview {
    CheckInQuickSetupView()
}
