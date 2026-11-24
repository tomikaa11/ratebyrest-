import Foundation

struct City: Identifiable, Hashable, Sendable {
    let name: String
    let countryCode: String
    let latitude: Double
    let longitude: Double

    var id: String { "\(countryCode)-\(name)" }
}

struct Country: Identifiable, Hashable, Sendable {
    let code: String
    let name: String
    let cities: [City]

    var id: String { code }
}

struct RestaurantPlace: Identifiable, Hashable, Sendable {
    let placeKey: String
    let name: String
    let address: String
    let city: String
    let countryCode: String
    let countryName: String
    let latitude: Double
    let longitude: Double

    var id: String { placeKey }

    static func makeKey(name: String, latitude: Double, longitude: Double) -> String {
        let normalized = name
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "hu_HU"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(normalized)|\(String(format: "%.4f", latitude))|\(String(format: "%.4f", longitude))"
    }
}

struct RestaurantRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let placeKey: String
    let name: String
    let city: String
    let countryCode: String
    let countryName: String
    let address: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case id
        case placeKey = "place_key"
        case name
        case city
        case countryCode = "country_code"
        case countryName = "country_name"
        case address
        case latitude
        case longitude
    }
}

struct RatingRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let restaurantID: UUID
    let userID: UUID
    let stars: Int

    enum CodingKeys: String, CodingKey {
        case id
        case restaurantID = "restaurant_id"
        case userID = "user_id"
        case stars
    }
}

struct DishRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let restaurantID: UUID
    let userID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case restaurantID = "restaurant_id"
        case userID = "user_id"
        case name
    }
}

struct DishRank: Identifiable, Hashable, Sendable {
    let name: String
    let votes: Int
    let myDishID: UUID?

    var id: String { name }
}

struct RestaurantStats: Sendable {
    var average: Double
    var count: Int
}

struct Favorite: Hashable, Sendable {
    var countryCode: String?
    var placeKey: String?
    var name: String?
    var city: String?
    var countryName: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?

    var country: Country? {
        guard let countryCode else { return nil }
        return CountryCatalog.all.first { $0.code == countryCode }
    }

    var restaurant: RestaurantPlace? {
        guard
            let placeKey, let name, let city, let countryCode, let countryName,
            let latitude, let longitude
        else { return nil }
        return RestaurantPlace(
            placeKey: placeKey,
            name: name,
            address: address ?? "",
            city: city,
            countryCode: countryCode,
            countryName: countryName,
            latitude: latitude,
            longitude: longitude
        )
    }
}

enum CountryCatalog {
    static let all: [Country] = [
        make("HU", "Magyarország", [
            ("Budapest", 47.4979, 19.0402),
            ("Debrecen", 47.5316, 21.6273),
            ("Szeged", 46.2530, 20.1414),
            ("Miskolc", 48.1035, 20.7784),
            ("Pécs", 46.0727, 18.2323),
            ("Győr", 47.6875, 17.6504),
            ("Nyíregyháza", 47.9554, 21.7167),
            ("Kecskemét", 46.8964, 19.6897),
            ("Székesfehérvár", 47.1860, 18.4221),
            ("Szombathely", 47.2307, 16.6218),
            ("Eger", 47.9025, 20.3772),
            ("Veszprém", 47.0930, 17.9115),
        ]),
        make("AT", "Ausztria", [
            ("Bécs", 48.2082, 16.3738),
            ("Graz", 47.0707, 15.4395),
            ("Salzburg", 47.8095, 13.0550),
            ("Innsbruck", 47.2692, 11.4041),
            ("Linz", 48.3069, 14.2858),
        ]),
        make("DE", "Németország", [
            ("Berlin", 52.5200, 13.4050),
            ("München", 48.1351, 11.5820),
            ("Hamburg", 53.5511, 9.9937),
            ("Köln", 50.9375, 6.9603),
            ("Frankfurt", 50.1109, 8.6821),
        ]),
        make("SK", "Szlovákia", [
            ("Pozsony", 48.1486, 17.1077),
            ("Kassa", 48.7164, 21.2611),
        ]),
        make("CZ", "Csehország", [
            ("Prága", 50.0755, 14.4378),
            ("Brno", 49.1951, 16.6068),
        ]),
        make("PL", "Lengyelország", [
            ("Varsó", 52.2297, 21.0122),
            ("Krakkó", 50.0647, 19.9450),
            ("Gdańsk", 54.3520, 18.6466),
            ("Wrocław", 51.1079, 17.0385),
        ]),
        make("RO", "Románia", [
            ("Bukarest", 44.4268, 26.1025),
            ("Kolozsvár", 46.7712, 23.6236),
        ]),
        make("HR", "Horvátország", [
            ("Zágráb", 45.8150, 15.9819),
            ("Split", 43.5081, 16.4402),
            ("Dubrovnik", 42.6507, 18.0944),
        ]),
        make("SI", "Szlovénia", [
            ("Ljubljana", 46.0569, 14.5058),
        ]),
        make("RS", "Szerbia", [
            ("Belgrád", 44.7866, 20.4489),
        ]),
        make("FR", "Franciaország", [
            ("Párizs", 48.8566, 2.3522),
            ("Lyon", 45.7640, 4.8357),
            ("Marseille", 43.2965, 5.3698),
            ("Toulouse", 43.6047, 1.4442),
            ("Nizza", 43.7102, 7.2620),
        ]),
        make("IT", "Olaszország", [
            ("Róma", 41.9028, 12.4964),
            ("Milánó", 45.4642, 9.1900),
            ("Nápoly", 40.8518, 14.2681),
            ("Torino", 45.0703, 7.6869),
            ("Firenze", 43.7696, 11.2558),
        ]),
        make("ES", "Spanyolország", [
            ("Madrid", 40.4168, -3.7038),
            ("Barcelona", 41.3874, 2.1686),
            ("Valencia", 39.4699, -0.3763),
            ("Sevilla", 37.3891, -5.9845),
            ("Bilbao", 43.2630, -2.9350),
        ]),
        make("PT", "Portugália", [
            ("Lisszabon", 38.7223, -9.1393),
            ("Porto", 41.1579, -8.6291),
        ]),
        make("GB", "Egyesült Királyság", [
            ("London", 51.5074, -0.1278),
            ("Manchester", 53.4808, -2.2426),
            ("Edinburgh", 55.9533, -3.1883),
            ("Birmingham", 52.4862, -1.8904),
            ("Glasgow", 55.8642, -4.2518),
        ]),
        make("IE", "Írország", [
            ("Dublin", 53.3498, -6.2603),
        ]),
        make("NL", "Hollandia", [
            ("Amszterdam", 52.3676, 4.9041),
            ("Rotterdam", 51.9244, 4.4777),
        ]),
        make("BE", "Belgium", [
            ("Brüsszel", 50.8503, 4.3517),
            ("Antwerpen", 51.2194, 4.4025),
        ]),
        make("CH", "Svájc", [
            ("Zürich", 47.3769, 8.5417),
            ("Genf", 46.2044, 6.1432),
            ("Bern", 46.9480, 7.4474),
        ]),
        make("GR", "Görögország", [
            ("Athén", 37.9838, 23.7275),
            ("Szaloniki", 40.6401, 22.9444),
        ]),
        make("TR", "Törökország", [
            ("Isztambul", 41.0082, 28.9784),
            ("Ankara", 39.9334, 32.8597),
        ]),
        make("SE", "Svédország", [
            ("Stockholm", 59.3293, 18.0686),
            ("Göteborg", 57.7089, 11.9746),
        ]),
        make("NO", "Norvégia", [
            ("Oslo", 59.9139, 10.7522),
            ("Bergen", 60.3913, 5.3221),
        ]),
        make("DK", "Dánia", [
            ("Koppenhága", 55.6761, 12.5683),
        ]),
        make("FI", "Finnország", [
            ("Helsinki", 60.1699, 24.9384),
        ]),
        make("US", "Egyesült Államok", [
            ("New York", 40.7128, -74.0060),
            ("Los Angeles", 34.0522, -118.2437),
            ("Chicago", 41.8781, -87.6298),
            ("Miami", 25.7617, -80.1918),
            ("San Francisco", 37.7749, -122.4194),
        ]),
        make("CA", "Kanada", [
            ("Toronto", 43.6532, -79.3832),
            ("Vancouver", 49.2827, -123.1207),
            ("Montréal", 45.5017, -73.5673),
        ]),
        make("JP", "Japán", [
            ("Tokió", 35.6762, 139.6503),
            ("Oszaka", 34.6937, 135.5023),
            ("Kiotó", 35.0116, 135.7681),
        ]),
        make("AU", "Ausztrália", [
            ("Sydney", -33.8688, 151.2093),
            ("Melbourne", -37.8136, 144.9631),
        ]),
    ]

    static func country(code: String) -> Country {
        all.first { $0.code == code } ?? all[0]
    }

    private static func make(_ code: String, _ name: String, _ rows: [(String, Double, Double)]) -> Country {
        Country(
            code: code,
            name: name,
            cities: rows.map { City(name: $0.0, countryCode: code, latitude: $0.1, longitude: $0.2) }
        )
    }
}
