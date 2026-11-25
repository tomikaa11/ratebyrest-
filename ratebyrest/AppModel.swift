import Foundation
import Observation

@Observable
final class AppModel {
    var countryCode = "HU"
    var userID: UUID?
    var userEmail: String?
    var schema: SchemaState = .unknown
    var favorite: Favorite?
    var tier = TierProgress()
    private var appliedFavoriteCountry = false

    var country: Country {
        CountryCatalog.country(code: countryCode)
    }

    var isSignedIn: Bool { userID != nil }

    func refreshSession() async {
        let session = await Backend.refreshSession()
        userID = session?.id
        userEmail = session?.email
        if userID == nil {
            favorite = nil
            tier = TierProgress()
            return
        }
        if let stored = try? await Backend.fetchFavorite() {
            favorite = stored
            if !appliedFavoriteCountry, let code = stored.countryCodes.first, CountryCatalog.all.contains(where: { $0.code == code }) {
                countryCode = code
                appliedFavoriteCountry = true
            }
        }
        await refreshTier()
    }

    func refreshTier() async {
        guard isSignedIn else {
            tier = TierProgress()
            return
        }
        if let progress = try? await Backend.fetchTier() {
            tier = progress
        }
    }

    func toggleFavoriteCountry(_ code: String) async throws {
        favorite = try await Backend.toggleFavoriteCountry(code, keeping: favorite, limit: tier.maxFavoriteCountries)
        appliedFavoriteCountry = true
        await refreshTier()
    }

    func saveFavoriteRestaurant(_ place: RestaurantPlace) async throws {
        favorite = try await Backend.saveFavoriteRestaurant(place, keeping: favorite)
    }

    func refreshSchema() async {
        schema = await Backend.pingSchema()
    }
}
