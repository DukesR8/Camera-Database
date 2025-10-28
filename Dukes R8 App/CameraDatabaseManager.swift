//
//  CameraDatabaseManager.swift
//  Dukes R8 App
//
//  Manages the large camera database with efficient loading and filtering
//

import Foundation
import CoreLocation
import OSLog
import Combine
import MapKit

// MARK: - Camera Database Models

struct CameraDatabaseEntry: Identifiable, Codable, Equatable {
    let id: String
    let latitude: Double
    let longitude: Double
    let type: CameraType
    let description: String?
    let direction: String?
    let timestamp: Date
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    // Parse speed limit from description if available
    var speedLimit: Int? {
        guard let description = description else { return nil }
        let pattern = "Limit: (\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
           let range = Range(match.range(at: 1), in: description) {
            return Int(String(description[range]))
        }
        return nil
    }
    
    // Parse enforcement directions from description
    var enforcementDirections: [String] {
        guard let description = description else { return [] }
        let pattern = "Monitors: ([A-Z, ]+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
           let range = Range(match.range(at: 1), in: description) {
            let directions = String(description[range])
            return directions.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return []
    }
    
    // Convert to CameraAlert for compatibility
    func toCameraAlert() -> CameraAlert {
        var enforcementDirection: Double? = nil
        if let directionString = direction, let directionValue = Double(directionString) {
            enforcementDirection = directionValue
        }
        
        return CameraAlert(
            id: id,
            latitude: latitude,
            longitude: longitude,
            type: type,
            streetName: description,
            timestamp: timestamp,
            enforcementDirection: enforcementDirection
        )
    }
}

// MARK: - Camera Database Bundle

struct CameraDatabaseBundle: Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let author: String
    let version: String
    let createdAt: Date
    let feeds: [CameraFeed]
}

struct CameraFeed: Codable, Equatable {
    let id: String
    let displayName: String
    let headers: [String: String]
    let isEnabled: Bool
    let userConfirmsRights: Bool
    let dartIntelligenceEnabled: Bool
    let isRiskScoreFeed: Bool
    let isHeatMapFeed: Bool
    let feedFormat: String
    let staticAlerts: [CameraDatabaseEntry]
}

// MARK: - Camera Database Manager

@MainActor
final class CameraDatabaseManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var allCameras: [CameraDatabaseEntry] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdate: Date?
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DukesR8", category: "CameraDatabaseManager")
    // Regional database URLs for optimal performance
    private let baseURL = "https://raw.githubusercontent.com/christophercosto-dev/dukes-cameras/main"
    
    // Location monitoring for border crossings
    private var currentRegion: String?
    private var lastLocation: CLLocation?
    
    /// Get the appropriate regional database URL based on location
    private func getRegionalDatabaseURL(for location: CLLocation) -> String {
        let region = determineRegion(for: location)
        return "\(baseURL)/camera_database/Camera_Database_\(region).json"
    }
    
    /// Determine the region based on location coordinates
    private func determineRegion(for location: CLLocation) -> String {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // Canada - Provinces and Territories
        if lat >= 49.0 && lat <= 60.0 && lon >= -120.0 && lon <= -110.0 {
            return "Alberta"
        } else if lat >= 48.0 && lat <= 60.0 && lon >= -139.0 && lon <= -114.0 {
            return "British_Columbia"
        } else if lat >= 41.0 && lat <= 57.0 && lon >= -95.0 && lon <= -74.0 {
            return "Ontario"
        } else if lat >= 44.0 && lat <= 63.0 && lon >= -80.0 && lon <= -57.0 {
            return "Quebec"
        } else if lat >= 49.0 && lat <= 60.0 && lon >= -102.0 && lon <= -95.0 {
            return "Manitoba"
        } else if lat >= 49.0 && lat <= 60.0 && lon >= -110.0 && lon <= -101.0 {
            return "Saskatchewan"
        } else if lat >= 43.0 && lat <= 47.0 && lon >= -66.0 && lon <= -59.0 {
            return "Nova_Scotia"
        } else if lat >= 45.0 && lat <= 48.0 && lon >= -69.0 && lon <= -63.0 {
            return "New_Brunswick"
        } else if lat >= 46.0 && lat <= 61.0 && lon >= -67.0 && lon <= -52.0 {
            return "Newfoundland"
        } else if lat >= 45.0 && lat <= 47.0 && lon >= -64.0 && lon <= -61.0 {
            return "Prince_Edward_Island"
        }
        
        // USA - All States
        else if lat >= 32.0 && lat <= 42.0 && lon >= -124.0 && lon <= -114.0 {
            return "California"
        } else if lat >= 25.0 && lat <= 36.0 && lon >= -106.0 && lon <= -93.0 {
            return "Texas"
        } else if lat >= 24.0 && lat <= 31.0 && lon >= -87.0 && lon <= -80.0 {
            return "Florida"
        } else if lat >= 40.0 && lat <= 45.0 && lon >= -80.0 && lon <= -71.0 {
            return "New_York"
        } else if lat >= 37.0 && lat <= 42.0 && lon >= -91.0 && lon <= -87.0 {
            return "Illinois"
        } else if lat >= 39.0 && lat <= 42.0 && lon >= -80.0 && lon <= -74.0 {
            return "Pennsylvania"
        } else if lat >= 38.0 && lat <= 42.0 && lon >= -84.0 && lon <= -80.0 {
            return "Ohio"
        } else if lat >= 41.0 && lat <= 48.0 && lon >= -90.0 && lon <= -82.0 {
            return "Michigan"
        } else if lat >= 30.0 && lat <= 35.0 && lon >= -85.0 && lon <= -80.0 {
            return "Georgia"
        } else if lat >= 33.0 && lat <= 36.0 && lon >= -84.0 && lon <= -75.0 {
            return "North_Carolina"
        } else if lat >= 36.0 && lat <= 39.0 && lon >= -83.0 && lon <= -75.0 {
            return "Virginia"
        } else if lat >= 35.0 && lat <= 36.0 && lon >= -90.0 && lon <= -81.0 {
            return "Tennessee"
        } else if lat >= 31.0 && lat <= 37.0 && lon >= -114.0 && lon <= -109.0 {
            return "Arizona"
        } else if lat >= 45.0 && lat <= 49.0 && lon >= -124.0 && lon <= -116.0 {
            return "Washington"
        } else if lat >= 37.0 && lat <= 41.0 && lon >= -109.0 && lon <= -102.0 {
            return "Colorado"
        } else if lat >= 35.0 && lat <= 42.0 && lon >= -120.0 && lon <= -114.0 {
            return "Nevada"
        } else if lat >= 42.0 && lat <= 46.0 && lon >= -124.0 && lon <= -116.0 {
            return "Oregon"
        } else if lat >= 37.0 && lat <= 42.0 && lon >= -114.0 && lon <= -109.0 {
            return "Utah"
        } else if lat >= 31.0 && lat <= 37.0 && lon >= -109.0 && lon <= -103.0 {
            return "New_Mexico"
        } else if lat >= 45.0 && lat <= 49.0 && lon >= -116.0 && lon <= -104.0 {
            return "Montana"
        } else if lat >= 41.0 && lat <= 45.0 && lon >= -111.0 && lon <= -104.0 {
            return "Wyoming"
        } else if lat >= 42.0 && lat <= 49.0 && lon >= -117.0 && lon <= -111.0 {
            return "Idaho"
        } else if lat >= 45.0 && lat <= 49.0 && lon >= -104.0 && lon <= -96.0 {
            return "North_Dakota"
        } else if lat >= 43.0 && lat <= 46.0 && lon >= -104.0 && lon <= -96.0 {
            return "South_Dakota"
        } else if lat >= 40.0 && lat <= 43.0 && lon >= -104.0 && lon <= -95.0 {
            return "Nebraska"
        } else if lat >= 37.0 && lat <= 40.0 && lon >= -102.0 && lon <= -94.0 {
            return "Kansas"
        } else if lat >= 33.0 && lat <= 37.0 && lon >= -103.0 && lon <= -94.0 {
            return "Oklahoma"
        } else if lat >= 33.0 && lat <= 36.0 && lon >= -94.0 && lon <= -89.0 {
            return "Arkansas"
        } else if lat >= 29.0 && lat <= 33.0 && lon >= -94.0 && lon <= -88.0 {
            return "Louisiana"
        } else if lat >= 30.0 && lat <= 35.0 && lon >= -91.0 && lon <= -88.0 {
            return "Mississippi"
        } else if lat >= 30.0 && lat <= 35.0 && lon >= -88.0 && lon <= -84.0 {
            return "Alabama"
        } else if lat >= 32.0 && lat <= 35.0 && lon >= -83.0 && lon <= -78.0 {
            return "South_Carolina"
        } else if lat >= 36.0 && lat <= 39.0 && lon >= -89.0 && lon <= -81.0 {
            return "Kentucky"
        } else if lat >= 37.0 && lat <= 40.0 && lon >= -82.0 && lon <= -77.0 {
            return "West_Virginia"
        } else if lat >= 37.0 && lat <= 40.0 && lon >= -79.0 && lon <= -75.0 {
            return "Maryland"
        } else if lat >= 38.0 && lat <= 40.0 && lon >= -75.0 && lon <= -74.0 {
            return "Delaware"
        } else if lat >= 38.0 && lat <= 41.0 && lon >= -75.0 && lon <= -73.0 {
            return "New_Jersey"
        } else if lat >= 40.0 && lat <= 42.0 && lon >= -73.0 && lon <= -71.0 {
            return "Connecticut"
        } else if lat >= 41.0 && lat <= 42.0 && lon >= -72.0 && lon <= -71.0 {
            return "Rhode_Island"
        } else if lat >= 41.0 && lat <= 43.0 && lon >= -73.0 && lon <= -69.0 {
            return "Massachusetts"
        } else if lat >= 42.0 && lat <= 45.0 && lon >= -73.0 && lon <= -71.0 {
            return "Vermont"
        } else if lat >= 42.0 && lat <= 45.0 && lon >= -72.0 && lon <= -70.0 {
            return "New_Hampshire"
        } else if lat >= 43.0 && lat <= 47.0 && lon >= -71.0 && lon <= -66.0 {
            return "Maine"
        } else if lat >= 42.0 && lat <= 47.0 && lon >= -92.0 && lon <= -86.0 {
            return "Wisconsin"
        } else if lat >= 43.0 && lat <= 49.0 && lon >= -97.0 && lon <= -89.0 {
            return "Minnesota"
        } else if lat >= 40.0 && lat <= 43.0 && lon >= -96.0 && lon <= -90.0 {
            return "Iowa"
        } else if lat >= 36.0 && lat <= 40.0 && lon >= -95.0 && lon <= -89.0 {
            return "Missouri"
        } else if lat >= 37.0 && lat <= 42.0 && lon >= -88.0 && lon <= -84.0 {
            return "Indiana"
        } else {
            // Default to Alberta for unknown locations
            return "Alberta"
        }
    }
    private let cacheKey = "CameraDatabaseCache"
    private let cacheExpiryKey = "CameraDatabaseCacheExpiry"
    private let cacheExpiryHours: TimeInterval = 24 * 7 // 7 days
    
    // 🚀 PERFORMANCE: Cache size limits to prevent buildup
    private let maxCacheSizeMB: Double = 50.0 // Maximum 50MB cache
    private let maxCacheEntries: Int = 5 // Maximum 5 regional databases cached
    
    // Regional sharding support
    private let regionalCacheKey = "CameraDatabaseRegionalCache"
    private let regionalCacheExpiryKey = "CameraDatabaseRegionalCacheExpiry"
    
    // MARK: - Initialization
    
    init() {
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    /// Load camera database from GitHub or cache
    func loadDatabase(for location: CLLocation? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // 🚀 PERFORMANCE: Clean up old cache entries periodically
        cleanupCache()
        
        do {
            // Check for region change if location is provided
            if let location = location {
                let newRegion = determineRegion(for: location)
                if self.currentRegion != newRegion {
                    log.info("🌍 Region changed from \(self.currentRegion ?? "unknown") to \(newRegion)")
                    self.currentRegion = newRegion
                    self.lastLocation = location
                    
                    // Clear cache for new region to force fresh download
                    clearCache()
                } else {
                    self.lastLocation = location
                }
            }
            
            // Check if we have valid cached data first (only if same region)
            if let cachedData = getCachedData(), !isCacheExpired(), self.currentRegion != nil {
                log.info("Using cached camera database with \(cachedData.count) cameras for region: \(self.currentRegion ?? "unknown")")
                await MainActor.run {
                    self.allCameras = cachedData
                    self.isLoading = false
                    self.lastUpdate = UserDefaults.standard.object(forKey: cacheExpiryKey) as? Date
                }
                return
            }
            
            // Download fresh data from GitHub
            log.info("Downloading camera database from GitHub...")
            let bundle = try await downloadDatabase(for: location ?? CLLocation(latitude: 0, longitude: 0))
            
            let cameras = bundle.feeds.flatMap { $0.staticAlerts }
            log.info("Downloaded \(cameras.count) cameras from database")
            
            // Cache the data
            cacheData(cameras)
            
            await MainActor.run {
                self.allCameras = cameras
                self.isLoading = false
                self.lastUpdate = Date()
                self.errorMessage = nil
                self.log.info("✅ Database loaded successfully with \(cameras.count) cameras")
            }
            
        } catch {
            log.error("Failed to load camera database: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load camera database: \(error.localizedDescription)"
            }
        }
    }
    
    /// Get cameras within a specific radius of a location
    func getCamerasNear(location: CLLocation, radius: Double = 20000) -> [CameraDatabaseEntry] {
        log.info("🔍 Searching for cameras near \(location.coordinate.latitude), \(location.coordinate.longitude) within \(radius/1000)km")
        log.info("📊 Total cameras in database: \(self.allCameras.count)")
        
        let nearbyCameras = self.allCameras.filter { camera in
            location.distance(from: camera.location) <= radius
        }
        
        log.info("📍 Found \(nearbyCameras.count) cameras within radius")
        return nearbyCameras
    }
    
    /// Convert database cameras to AlertItems for map display (optimized for performance)
    func getCameraAlertItems(location: CLLocation, radius: Double = 20000) -> [AlertItem] {
        // 🚀 PERFORMANCE: Only load cameras for the current region
        let cameras = getCamerasNear(location: location, radius: radius)
        
        // Limit to reasonable number for performance
        let maxCameras = 100
        let limitedCameras = Array(cameras.prefix(maxCameras))
        
        if cameras.count > maxCameras {
            log.info("⚠️ Performance: Limited to \(maxCameras) cameras out of \(cameras.count) found")
        }
        
        return limitedCameras.map { camera in
            AlertItem(
                id: camera.id,
                coordinate: camera.coordinate,
                type: camera.type.rawValue, // "SPEED_CAMERA" or "RED_LIGHT_CAMERA"
                subtype: camera.direction ?? "All Directions",
                street: camera.description,
                publishedAt: camera.timestamp,
                source: "Camera Database",
                metadata: [
                    "direction": camera.direction as Any,
                    "description": camera.description as Any
                ]
            )
        }
    }
    
    /// Load cameras for a specific region (optimized for performance)
    func loadCamerasForRegion(_ region: MKCoordinateRegion) async {
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let _ = max(region.span.latitudeDelta, region.span.longitudeDelta) * 111000 / 2 // Convert to meters
        
        // If we already have cameras loaded and they cover the region, no need to reload
        if !allCameras.isEmpty {
            let existingRadius: CLLocationDistance = 50000 // 50km radius check
            let hasNearbyCameras = allCameras.contains { camera in
                center.distance(from: camera.location) <= existingRadius
            }
            
            if hasNearbyCameras {
                log.info("Using existing camera data for region")
                return
            }
        }
        
        // Load database if not already loaded
        if self.allCameras.isEmpty {
            await self.loadDatabase()
        }
    }
    
    /// Get cameras for a specific map region
    func getCamerasInRegion(_ region: MKCoordinateRegion) -> [CameraDatabaseEntry] {
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let radius = max(region.span.latitudeDelta, region.span.longitudeDelta) * 111000 / 2 // Convert to meters
        
        return getCamerasNear(location: center, radius: radius)
    }
    
    /// Get cameras by type
    func getCamerasByType(_ type: CameraType) -> [CameraDatabaseEntry] {
        return allCameras.filter { $0.type == type }
    }
    
    /// Convert database entries to CameraAlerts for compatibility
    func getCameraAlertsNear(location: CLLocation, radius: Double = 20000) -> [CameraAlert] {
        return getCamerasNear(location: location, radius: radius).map { $0.toCameraAlert() }
    }
    
    /// Force refresh the database
    func refreshDatabase() async {
        clearCache()
        await loadDatabase()
    }
    
    // MARK: - Private Methods
    
    private func downloadDatabase(for location: CLLocation) async throws -> CameraDatabaseBundle {
        let regionalURL = getRegionalDatabaseURL(for: location)
        guard let url = URL(string: regionalURL) else {
            throw CameraDatabaseError.invalidURL
        }
        
        log.info("🌍 Loading regional database for region: \(self.determineRegion(for: location))")
        
        // Configure URLSession for optimal caching
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .useProtocolCachePolicy
        config.urlCache = URLCache.shared
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        let session = URLSession(configuration: config)
        
        // Create request with proper headers for CDN optimization
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.cachePolicy = .useProtocolCachePolicy
        
        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let downloadTime = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CameraDatabaseError.downloadFailed
        }
        
        // Log performance metrics
        let dataSizeMB = Double(data.count) / (1024 * 1024)
        log.info("Downloaded camera database: \(String(format: "%.2f", dataSizeMB))MB in \(String(format: "%.2f", downloadTime))s")
        
        // Handle different response codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 304:
            // Not Modified - use cached data
            log.info("Database not modified, using cached version")
            if let cachedData = getCachedData() {
                return CameraDatabaseBundle(
                    id: "cached",
                    name: "Cached Database",
                    description: "Cached camera database",
                    author: "Cached",
                    version: "cached",
                    createdAt: Date(),
                    feeds: [CameraFeed(
                        id: "cached-feed",
                        displayName: "Cached Feed",
                        headers: [:],
                        isEnabled: true,
                        userConfirmsRights: true,
                        dartIntelligenceEnabled: false,
                        isRiskScoreFeed: false,
                        isHeatMapFeed: false,
                        feedFormat: "json",
                        staticAlerts: cachedData
                    )]
                )
            } else {
                throw CameraDatabaseError.downloadFailed
            }
        case 404:
            // Regional file not found - fallback to full database
            log.warning("Regional database not found, falling back to full database")
            return try await downloadFullDatabase()
        default:
            throw CameraDatabaseError.downloadFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(CameraDatabaseBundle.self, from: data)
    }
    
    /// Fallback method to download the full database when regional files are not available
    private func downloadFullDatabase() async throws -> CameraDatabaseBundle {
        let fullDatabaseURL = "https://raw.githubusercontent.com/christophercosto-dev/dukes-cameras/main/camera_database/Camera_Database_Bundle_Sorted.json"
        guard let url = URL(string: fullDatabaseURL) else {
            throw CameraDatabaseError.invalidURL
        }
        
        log.info("📦 Downloading full database as fallback...")
        
        // Configure URLSession for optimal caching
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .useProtocolCachePolicy
        config.urlCache = URLCache.shared
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        let session = URLSession(configuration: config)
        
        // Create request with proper headers for CDN optimization
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.cachePolicy = .useProtocolCachePolicy
        
        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let downloadTime = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CameraDatabaseError.downloadFailed
        }
        
        // Log performance metrics
        let dataSizeMB = Double(data.count) / (1024 * 1024)
        log.info("Downloaded full database: \(String(format: "%.2f", dataSizeMB))MB in \(String(format: "%.2f", downloadTime))s")
        
        guard httpResponse.statusCode == 200 else {
            throw CameraDatabaseError.downloadFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(CameraDatabaseBundle.self, from: data)
    }
    
    private func loadCachedData() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            allCameras = try decoder.decode([CameraDatabaseEntry].self, from: data)
            lastUpdate = UserDefaults.standard.object(forKey: cacheExpiryKey) as? Date
            log.info("Loaded \(self.allCameras.count) cameras from cache")
        } catch {
            log.error("Failed to load cached camera data: \(error.localizedDescription)")
        }
    }
    
    private func cacheData(_ cameras: [CameraDatabaseEntry]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cameras)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheExpiryKey)
            log.info("Cached \(cameras.count) cameras")
        } catch {
            log.error("Failed to cache camera data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Location Monitoring
    
    /// Check if location has changed significantly and reload database if needed
    func checkLocationUpdate(_ newLocation: CLLocation) {
        // Only check for region changes if we have a previous location
        guard let lastLocation = self.lastLocation else {
            self.lastLocation = newLocation
            return
        }
        
        // Check if we've moved to a different region
        let newRegion = determineRegion(for: newLocation)
        if self.currentRegion != newRegion {
            log.info("🌍 Border crossing detected: \(self.currentRegion ?? "unknown") → \(newRegion)")
            
            // Reload database for new region
            Task {
                await self.loadDatabase(for: newLocation)
            }
        } else {
            self.lastLocation = newLocation
        }
    }
    
    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheExpiryKey)
        log.info("🗑️ Cache cleared for region change")
    }
    
    // 🚀 PERFORMANCE: Clean up old cache entries to prevent buildup
    private func cleanupCache() {
        // Clean up expired cache entries
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let cacheKeys = allKeys.filter { $0.hasPrefix("CameraDatabaseCache") }
        
        var totalSizeMB: Double = 0
        var validEntries = 0
        
        for key in cacheKeys {
            if let data = UserDefaults.standard.data(forKey: key) {
                let sizeMB = Double(data.count) / (1024 * 1024)
                totalSizeMB += sizeMB
                
                // Check if cache is expired
                if key.contains("Expiry") {
                    if let expiryDate = UserDefaults.standard.object(forKey: key) as? Date {
                        if Date().timeIntervalSince(expiryDate) > cacheExpiryHours * 3600 {
                            // Remove expired cache
                            UserDefaults.standard.removeObject(forKey: key)
                            UserDefaults.standard.removeObject(forKey: key.replacingOccurrences(of: "Expiry", with: ""))
                            log.info("🗑️ Removed expired cache: \(key)")
                        } else {
                            validEntries += 1
                        }
                    }
                }
            }
        }
        
        // If cache is too large, remove oldest entries
        if totalSizeMB > maxCacheSizeMB || validEntries > maxCacheEntries {
            log.warning("🧹 Cache cleanup needed: \(String(format: "%.1f", totalSizeMB))MB, \(validEntries) entries")
            clearAllCache()
        }
    }
    
    private func clearAllCache() {
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let cacheKeys = allKeys.filter { $0.hasPrefix("CameraDatabaseCache") }
        
        for key in cacheKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        log.info("🗑️ Cleared all camera database cache (\(cacheKeys.count) entries)")
    }
    
    private func getCachedData() -> [CameraDatabaseEntry]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([CameraDatabaseEntry].self, from: data)
        } catch {
            log.error("Failed to decode cached camera data: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func isCacheExpired() -> Bool {
        guard let cacheDate = UserDefaults.standard.object(forKey: cacheExpiryKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(cacheDate) > cacheExpiryHours * 3600
    }
}

// MARK: - Errors

enum CameraDatabaseError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid database URL"
        case .downloadFailed:
            return "Failed to download camera database"
        case .decodingFailed:
            return "Failed to decode camera database"
        }
    }
}
