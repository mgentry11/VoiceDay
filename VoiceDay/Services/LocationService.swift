import Foundation
import CoreLocation
import Combine

/// Manages location tracking and geofence monitoring for checkout checklists
@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    // MARK: - Published State

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var savedLocations: [SavedLocation] = []
    @Published var locationExitTriggered: SavedLocation?
    @Published var isMonitoring = false

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private let geofenceRadius: CLLocationDistance = 100 // meters

    // MARK: - Models

    struct SavedLocation: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var checklistEnabled: Bool
        var icon: String // SF Symbol name
        var createdAt: Date

        init(name: String, latitude: Double, longitude: Double, icon: String = "mappin.circle.fill") {
            self.id = UUID()
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.checklistEnabled = true
            self.icon = icon
            self.createdAt = Date()
        }

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        var region: CLCircularRegion {
            let region = CLCircularRegion(
                center: coordinate,
                radius: 100, // 100 meters
                identifier: id.uuidString
            )
            region.notifyOnEntry = false
            region.notifyOnExit = true
            return region
        }
    }

    // MARK: - Preset Location Types

    enum LocationPreset: String, CaseIterable {
        case gym = "Gym"
        case work = "Work"
        case home = "Home"
        case school = "School"
        case therapy = "Therapy"
        case store = "Store"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .gym: return "dumbbell.fill"
            case .work: return "building.2.fill"
            case .home: return "house.fill"
            case .school: return "graduationcap.fill"
            case .therapy: return "heart.text.square.fill"
            case .store: return "cart.fill"
            case .custom: return "mappin.circle.fill"
            }
        }

        var defaultChecklistItems: [String] {
            switch self {
            case .gym:
                return [
                    "Log workout in fitness app",
                    "Post-workout protein",
                    "Stretch & cool down",
                    "Schedule next workout",
                    "Hydrate"
                ]
            case .work:
                return [
                    "Save all work",
                    "Update task list",
                    "Check tomorrow's calendar",
                    "Pack up belongings",
                    "Clear desk"
                ]
            case .home:
                return [
                    "Keys & wallet",
                    "Phone charged",
                    "Lights off",
                    "Lock doors"
                ]
            case .school:
                return [
                    "Homework packed",
                    "Check assignments due",
                    "Books & supplies",
                    "Lunch/snacks"
                ]
            case .therapy:
                return [
                    "Schedule next appointment",
                    "Note any homework",
                    "Self-care check"
                ]
            case .store:
                return [
                    "Check shopping list complete",
                    "Check receipt",
                    "Cart returned"
                ]
            case .custom:
                return []
            }
        }
    }

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = false
        loadSavedLocations()
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }

    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var hasAlwaysPermission: Bool {
        authorizationStatus == .authorizedAlways
    }

    // MARK: - Location Updates

    func startUpdatingLocation() {
        guard hasLocationPermission else {
            requestAuthorization()
            return
        }
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func getCurrentLocation() async -> CLLocation? {
        guard hasLocationPermission else {
            requestAuthorization()
            return nil
        }

        startUpdatingLocation()

        // Wait for location update
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        stopUpdatingLocation()
        return currentLocation
    }

    // MARK: - Saved Locations Management

    func addLocation(_ location: SavedLocation) {
        savedLocations.append(location)
        saveLocations()

        if location.checklistEnabled && hasAlwaysPermission {
            startMonitoringLocation(location)
        }
    }

    func addLocationAtCurrentPosition(name: String, preset: LocationPreset) async -> SavedLocation? {
        guard let current = await getCurrentLocation() else {
            print("Failed to get current location")
            return nil
        }

        let location = SavedLocation(
            name: name,
            latitude: current.coordinate.latitude,
            longitude: current.coordinate.longitude,
            icon: preset.icon
        )

        addLocation(location)
        return location
    }

    func removeLocation(id: UUID) {
        if let location = savedLocations.first(where: { $0.id == id }) {
            stopMonitoringLocation(location)
        }
        savedLocations.removeAll { $0.id == id }
        saveLocations()
    }

    func updateLocation(_ location: SavedLocation) {
        if let index = savedLocations.firstIndex(where: { $0.id == location.id }) {
            let wasMonitoring = savedLocations[index].checklistEnabled
            savedLocations[index] = location
            saveLocations()

            // Update monitoring if needed
            if wasMonitoring && !location.checklistEnabled {
                stopMonitoringLocation(location)
            } else if !wasMonitoring && location.checklistEnabled && hasAlwaysPermission {
                startMonitoringLocation(location)
            }
        }
    }

    func toggleChecklistEnabled(id: UUID) {
        if let index = savedLocations.firstIndex(where: { $0.id == id }) {
            savedLocations[index].checklistEnabled.toggle()
            let location = savedLocations[index]
            saveLocations()

            if location.checklistEnabled && hasAlwaysPermission {
                startMonitoringLocation(location)
            } else {
                stopMonitoringLocation(location)
            }
        }
    }

    // MARK: - Geofence Monitoring

    func startMonitoringAllLocations() {
        guard hasAlwaysPermission else {
            print("Need 'Always' location permission for geofencing")
            return
        }

        for location in savedLocations where location.checklistEnabled {
            startMonitoringLocation(location)
        }
        isMonitoring = true
        print("Started monitoring \(savedLocations.filter { $0.checklistEnabled }.count) locations")
    }

    func stopMonitoringAllLocations() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        isMonitoring = false
        print("Stopped monitoring all locations")
    }

    private func startMonitoringLocation(_ location: SavedLocation) {
        guard hasAlwaysPermission else { return }

        let region = location.region
        locationManager.startMonitoring(for: region)
        print("Started monitoring: \(location.name)")
    }

    private func stopMonitoringLocation(_ location: SavedLocation) {
        let region = location.region
        locationManager.stopMonitoring(for: region)
        print("Stopped monitoring: \(location.name)")
    }

    // MARK: - Clear Exit Trigger

    func clearExitTrigger() {
        locationExitTriggered = nil
    }

    // MARK: - Test Trigger (for development)

    func simulateExitFromLocation(_ location: SavedLocation) {
        print("Simulating exit from: \(location.name)")
        locationExitTriggered = location
    }

    // MARK: - Persistence

    private func saveLocations() {
        if let encoded = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(encoded, forKey: "saved_locations")
        }
    }

    private func loadSavedLocations() {
        if let data = UserDefaults.standard.data(forKey: "saved_locations"),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            savedLocations = decoded
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.updateAuthorizationStatus()

            // If we now have always permission, start monitoring
            if self.hasAlwaysPermission && !self.savedLocations.isEmpty {
                self.startMonitoringAllLocations()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            guard let circularRegion = region as? CLCircularRegion else { return }

            // Find the saved location
            if let location = self.savedLocations.first(where: { $0.id.uuidString == circularRegion.identifier }) {
                print("Exited location: \(location.name)")
                self.locationExitTriggered = location
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Optional: Track entering locations too
        Task { @MainActor in
            guard let circularRegion = region as? CLCircularRegion else { return }
            if let location = self.savedLocations.first(where: { $0.id.uuidString == circularRegion.identifier }) {
                print("Entered location: \(location.name)")
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
}
