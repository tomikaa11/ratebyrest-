import Foundation
import SwiftUI

struct ExploreView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var path = NavigationPath()
    @State private var showAccount = false
    @State private var message: String?

    private var cities: [City] {
        let all = model.country.cities
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.localizedStandardContains(trimmed) }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $path) {
            List {
                if model.schema == .missing {
                    Section {
                        SchemaBanner()
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }
                Section {
                    FavoriteCard(path: $path)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                }
                Section {
                    CountryPicker(countryCode: $model.countryCode)
                        .labelsHidden()
                    Button {
                        Task { await markFavoriteCountry() }
                    } label: {
                        Label(
                            model.favorite?.countryCode == model.countryCode ? "Kedvenc ország" : "Kedvenc országnak jelölöm",
                            systemImage: model.favorite?.countryCode == model.countryCode ? "heart.fill" : "heart"
                        )
                    }
                    .foregroundStyle(Theme.accent)
                } header: {
                    Text("Ország")
                } footer: {
                    Text("A városok a választott ország nagyobb települései. Az éttermek a térkép találatai.")
                }
                Section("Városok") {
                    if cities.isEmpty {
                        Text("Nincs ilyen város a listában.")
                            .foregroundStyle(Theme.muted)
                    } else {
                        ForEach(cities) { city in
                            NavigationLink(value: city) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.name)
                                        .foregroundStyle(Theme.ink)
                                    Text(model.country.name)
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Éttermek")
            .navigationDestination(for: City.self) { city in
                CityRestaurantsView(city: city)
            }
            .navigationDestination(for: RestaurantPlace.self) { place in
                RestaurantDetailView(place: place)
            }
            .searchable(text: $query, prompt: "Város keresése")
            .onAppear(perform: openDebugCity)
            .sheet(isPresented: $showAccount) {
                NavigationStack {
                    AccountView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Bezárás") { showAccount = false }
                            }
                        }
                }
            }
            .alert("Kedvenc", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("Rendben", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func markFavoriteCountry() async {
        guard model.isSignedIn else {
            showAccount = true
            return
        }
        do {
            try await model.saveFavoriteCountry(model.countryCode)
        } catch {
            message = error.localizedDescription
        }
    }

    private func openDebugCity() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--open-budapest"),
              path.isEmpty,
              let city = model.country.cities.first(where: { $0.name == "Budapest" })
        else { return }
        path.append(city)
        #endif
    }
}

private struct FavoriteCard: View {
    @Environment(AppModel.self) private var model
    @Binding var path: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Kedvenc hely", systemImage: "heart.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            if let place = model.favorite?.restaurant {
                Button {
                    path.append(place)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text("\(place.city), \(place.countryName)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else if model.isSignedIn {
                Text("Még nincs kedvenc éttermed. Nyiss meg egy helyet, és jelöld meg.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                Text("Jelentkezz be, és jelölj meg egy kedvenc éttermet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            if let country = model.favorite?.country {
                Text("Kedvenc ország: \(country.name)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.accent, lineWidth: 1.5)
        )
    }
}

struct CityRestaurantsView: View {
    @Environment(AppModel.self) private var model
    let city: City

    @State private var places: [RestaurantPlace] = []
    @State private var stats: [String: RestaurantStats] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Text("A térkép találatai \(city.name) környékén, nem a város minden étterme.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            if isLoading && places.isEmpty {
                ProgressView("Éttermek keresése…")
            } else if let errorMessage, places.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage)
                    Button("Újra") { Task { await load() } }
                }
            } else if places.isEmpty {
                Text("Ebben a körzetben nincs találat.")
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(places) { place in
                    NavigationLink(value: place) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text(place.address)
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                                .lineLimit(2)
                            if let rating = stats[place.placeKey] {
                                AverageLabel(stats: rating)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(city.name)
        .navigationDestination(for: RestaurantPlace.self) { place in
            RestaurantDetailView(place: place)
        }
        .refreshable { await load() }
        .task(id: city.id) { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let found = try await RestaurantSearch.search(city: city, countryName: model.country.name)
            places = found
            stats = await Backend.stats(for: found)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
