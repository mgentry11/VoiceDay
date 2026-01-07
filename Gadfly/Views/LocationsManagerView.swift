import SwiftUI
import CoreLocation

/// Manage saved locations and their checkout checklists
struct LocationsManagerView: View {
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var checkoutService = CheckoutChecklistService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAddLocation = false
    @State private var showLocationPermissionAlert = false
    @State private var selectedLocation: LocationService.SavedLocation?

    var body: some View {
        NavigationStack {
            List {
                // Permission status section
                if !locationService.hasLocationPermission {
                    permissionSection
                } else if !locationService.hasAlwaysPermission {
                    alwaysPermissionSection
                }

                // Saved locations
                if !locationService.savedLocations.isEmpty {
                    savedLocationsSection
                }

                // Add location button
                addLocationSection

                // Test section (for development)
                #if DEBUG
                testSection
                #endif
            }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddLocation) {
                AddLocationView()
            }
            .sheet(item: $selectedLocation) { location in
                LocationDetailView(location: location)
            }
        }
    }

    // MARK: - Permission Sections

    private var permissionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "location.slash.fill")
                        .foregroundStyle(.orange)
                    Text("Location Access Required")
                        .fontWeight(.semibold)
                }

                Text("Enable location access to trigger checkout checklists when you leave saved places.")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)

                Button {
                    locationService.requestAuthorization()
                } label: {
                    Text("Enable Location")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeColors.accent)
                        .cornerRadius(10)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var alwaysPermissionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "location.circle")
                        .foregroundStyle(.yellow)
                    Text("Background Location Needed")
                        .fontWeight(.semibold)
                }

                Text("For automatic checkout triggers, enable 'Always' location access in Settings.")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeColors.accent)
                        .cornerRadius(10)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Saved Locations Section

    private var savedLocationsSection: some View {
        Section("Saved Locations") {
            ForEach(locationService.savedLocations) { location in
                Button {
                    selectedLocation = location
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: location.icon)
                            .font(.title2)
                            .foregroundStyle(themeColors.accent)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name)
                                .font(.body)
                                .foregroundStyle(themeColors.text)

                            let itemCount = checkoutService.getChecklist(for: location.id).count
                            Text("\(itemCount) checklist items")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                        }

                        Spacer()

                        // Monitoring indicator
                        if location.checklistEnabled && locationService.hasAlwaysPermission {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteLocations)
        }
    }

    // MARK: - Add Location Section

    private var addLocationSection: some View {
        Section {
            Button {
                showAddLocation = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(themeColors.accent)
                    Text("Add Location")
                        .foregroundStyle(themeColors.accent)
                }
            }
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        Section("Development") {
            if let firstLocation = locationService.savedLocations.first {
                Button {
                    locationService.simulateExitFromLocation(firstLocation)
                } label: {
                    HStack {
                        Image(systemName: "play.circle")
                            .foregroundStyle(.orange)
                        Text("Test Exit from \(firstLocation.name)")
                            .foregroundStyle(.orange)
                    }
                }
            }

            HStack {
                Text("Monitoring")
                    .foregroundStyle(themeColors.text)
                Spacer()
                Text(locationService.isMonitoring ? "Active" : "Inactive")
                    .foregroundStyle(locationService.isMonitoring ? .green : themeColors.subtext)
            }

            HStack {
                Text("Permission")
                    .foregroundStyle(themeColors.text)
                Spacer()
                Text(permissionStatusText)
                    .foregroundStyle(permissionStatusColor)
            }
        }
    }

    private var permissionStatusText: String {
        switch locationService.authorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default: return "Unknown"
        }
    }

    private var permissionStatusColor: Color {
        switch locationService.authorizationStatus {
        case .authorizedAlways: return .green
        case .authorizedWhenInUse: return .yellow
        case .denied, .restricted: return .red
        default: return themeColors.subtext
        }
    }

    // MARK: - Actions

    private func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            let location = locationService.savedLocations[index]
            locationService.removeLocation(id: location.id)
        }
    }
}

// MARK: - Add Location View

struct AddLocationView: View {
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var checkoutService = CheckoutChecklistService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: LocationService.LocationPreset = .gym
    @State private var customName = ""
    @State private var isGettingLocation = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preset selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Location Type")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(LocationService.LocationPreset.allCases, id: \.self) { preset in
                            Button {
                                selectedPreset = preset
                                if preset != .custom {
                                    customName = preset.rawValue
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: preset.icon)
                                        .font(.title2)
                                    Text(preset.rawValue)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedPreset == preset ? themeColors.accent.opacity(0.2) : themeColors.secondary)
                                .foregroundStyle(selectedPreset == preset ? themeColors.accent : themeColors.text)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedPreset == preset ? themeColors.accent : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Name")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)

                    TextField("e.g., Planet Fitness", text: $customName)
                        .padding()
                        .background(themeColors.secondary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // Default checklist preview
                if !selectedPreset.defaultChecklistItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Checklist")
                            .font(.headline)
                            .foregroundStyle(themeColors.text)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(selectedPreset.defaultChecklistItems, id: \.self) { item in
                                HStack {
                                    Image(systemName: "circle")
                                        .font(.caption)
                                        .foregroundStyle(themeColors.subtext)
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundStyle(themeColors.text)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(themeColors.secondary)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Save button
                VStack(spacing: 12) {
                    if isGettingLocation {
                        HStack {
                            ProgressView()
                            Text("Getting your location...")
                                .foregroundStyle(themeColors.subtext)
                        }
                    }

                    Button {
                        saveLocation()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Save Current Location")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(customName.isEmpty ? Color.gray : themeColors.accent)
                        .cornerRadius(12)
                    }
                    .disabled(customName.isEmpty || isGettingLocation)

                    Text("Make sure you're at the location you want to save")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveLocation() {
        isGettingLocation = true

        Task {
            if let location = await locationService.addLocationAtCurrentPosition(name: customName, preset: selectedPreset) {
                // Initialize default checklist
                checkoutService.initializeDefaultChecklist(for: location, preset: selectedPreset)

                await MainActor.run {
                    isGettingLocation = false
                    dismiss()
                }
            } else {
                await MainActor.run {
                    isGettingLocation = false
                    errorMessage = "Could not get your current location. Please check location permissions."
                    showError = true
                }
            }
        }
    }
}

// MARK: - Location Detail View

struct LocationDetailView: View {
    let location: LocationService.SavedLocation

    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var checkoutService = CheckoutChecklistService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAddItem = false
    @State private var newItemTitle = ""
    @State private var showDeleteConfirmation = false

    private var checklistItems: [CheckoutChecklistService.ChecklistItem] {
        checkoutService.getChecklist(for: location.id)
    }

    var body: some View {
        NavigationStack {
            List {
                // Location info
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: location.icon)
                            .font(.largeTitle)
                            .foregroundStyle(themeColors.accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Saved \(location.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Monitoring toggle
                Section {
                    Toggle(isOn: Binding(
                        get: { location.checklistEnabled },
                        set: { _ in locationService.toggleChecklistEnabled(id: location.id) }
                    )) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(themeColors.accent)
                            Text("Checkout Reminders")
                        }
                    }

                    if location.checklistEnabled && !locationService.hasAlwaysPermission {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Requires 'Always' location permission")
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                        }
                    }
                }

                // Checklist items
                Section("Checklist Items") {
                    ForEach(checklistItems) { item in
                        HStack {
                            if item.isExternalAppLink {
                                Image(systemName: "arrow.up.forward.app.fill")
                                    .foregroundStyle(themeColors.accent)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(themeColors.subtext)
                            }

                            Text(item.title)
                                .foregroundStyle(themeColors.text)

                            Spacer()

                            if !item.isActive {
                                Text("Disabled")
                                    .font(.caption)
                                    .foregroundStyle(themeColors.subtext)
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: moveItems)

                    Button {
                        showAddItem = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(themeColors.accent)
                            Text("Add Item")
                                .foregroundStyle(themeColors.accent)
                        }
                    }
                }

                // Delete location
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Location")
                        }
                    }
                }
            }
            .navigationTitle("Location Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .alert("Add Checklist Item", isPresented: $showAddItem) {
                TextField("Item title", text: $newItemTitle)
                Button("Cancel", role: .cancel) {
                    newItemTitle = ""
                }
                Button("Add") {
                    if !newItemTitle.isEmpty {
                        checkoutService.addItem(to: location.id, title: newItemTitle)
                        newItemTitle = ""
                    }
                }
            }
            .alert("Delete Location?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    locationService.removeLocation(id: location.id)
                    dismiss()
                }
            } message: {
                Text("This will also delete the checkout checklist for \(location.name).")
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = checklistItems[index]
            checkoutService.removeItem(from: location.id, itemId: item.id)
        }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        checkoutService.moveItem(in: location.id, from: source, to: destination)
    }
}

// MARK: - Preview

#Preview {
    LocationsManagerView()
}
