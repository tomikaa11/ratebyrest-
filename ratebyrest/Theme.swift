import SwiftUI

enum Theme {
    // Dinamikus gasztro-piros paletta
    static let accent = Color(red: 0.90, green: 0.22, blue: 0.21)       // #E53935 élénk gasztro-piros
    static let accentHover = Color(red: 0.83, green: 0.18, blue: 0.18)  // #D32F2F
    static let background = Color(red: 0.984, green: 0.973, blue: 0.957) // #FBF8F4 meleg törtfehér háttér
    static let card = Color.white
    static let peach = Color(red: 1.0, green: 0.945, blue: 0.910)      // #FFF1E8 hero barack háttér
    static let line = Color(red: 0.929, green: 0.902, blue: 0.875)      // #EDE6DF finom szegély
    static let gold = Color(red: 1.0, green: 0.784, blue: 0.239)       // #FFC83D arany csillag & #1 jelvény
    static let ink = Color(red: 0.11, green: 0.09, blue: 0.08)          // #1C1714 sötét főszöveg
    static let muted = Color(red: 0.48, green: 0.44, blue: 0.41)        // #7A6F68 másodlagos szöveg
    static let space = Color.white
}

struct StarRating: View {
    let value: Int
    var interactive = false
    var onSelect: (Int) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= value ? "star.fill" : "star")
                    .font(interactive ? .title2 : .subheadline)
                    .foregroundStyle(Theme.gold)
                    .onTapGesture {
                        if interactive {
                            onSelect(star)
                        }
                    }
                    .accessibilityLabel("\(star) csillag")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CountryPicker: View {
    @Binding var countryCode: String

    var body: some View {
        Picker("Country", selection: $countryCode) {
            ForEach(CountryCatalog.all) { country in
                Text(country.name).tag(country.code)
            }
        }
        .pickerStyle(.menu)
    }
}

struct SchemaBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ratings are not connected yet")
                .font(.subheadline.weight(.semibold))
            Text("In Supabase, open the SQL Editor, paste supabase/schema.sql, and run it again. Ratings, dishes, and favorite countries will then save to your account.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
    }
}

struct AverageLabel: View {
    let stats: RestaurantStats

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(Theme.gold)
            Text(stats.average.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))))
                .font(.subheadline.weight(.semibold))
            Text("(\(stats.count))")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
    }
}

