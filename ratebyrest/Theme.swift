import SwiftUI

enum Theme {
    static let background = Color.white
    static let card = Color.white
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let muted = Color(red: 0.38, green: 0.38, blue: 0.38)
    static let accent = Color(red: 0.80, green: 0.07, blue: 0.11)
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
                    .foregroundStyle(Theme.accent)
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
        Picker("Ország", selection: $countryCode) {
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
            Text("Az értékelések még nincsenek bekötve")
                .font(.subheadline.weight(.semibold))
            Text("Supabase → SQL Editor → illeszd be a supabase/schema.sql fájlt, és futtasd le. Utána az értékelések, az ételek és a kedvencek a fiókodhoz mentődnek.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AverageLabel: View {
    let stats: RestaurantStats

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(Theme.accent)
            Text(stats.average.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "hu_HU"))))
                .font(.subheadline.weight(.semibold))
            Text("(\(stats.count))")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
    }
}
