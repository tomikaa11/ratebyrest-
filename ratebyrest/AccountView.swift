import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var message: String?
    @State private var confirmDelete = false

    var body: some View {
        Form {
            if model.schema == .missing {
                Section {
                    SchemaBanner()
                }
            }
            if model.isSignedIn {
                Section("Level") {
                    Text(model.tier.title)
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                    Text("Ratings: \(model.tier.ratingCount), good ones: \(model.tier.goodRatingCount)")
                    Text("Favorite countries: \(model.tier.favoriteCountryCount)/\(model.tier.maxFavoriteCountries)")
                    Text(model.tier.nextHint)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                Section("Account") {
                    Text(model.userEmail ?? "Signed in")
                    if let favorite = model.favorite, !favorite.countries.isEmpty {
                        Text("Favorite countries: \(favorite.countries.map(\.name).joined(separator: ", "))")
                    }
                    if let place = model.favorite?.restaurant {
                        Text("Favorite place: \(place.name), \(place.city)")
                    }
                    Button("Sign out") { Task { await signOut() } }
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                }
                Section("Your data") {
                    Text("Your email, ratings, dishes, favorite countries, and favorite restaurant are stored in Supabase on your account. Your location is only used for directions and is not saved.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Section("Sign in") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password, at least 6 characters", text: $password)
                        .textContentType(.password)
                    Button(isWorking ? "Working…" : "Sign in") {
                        Task { await signIn() }
                    }
                    .disabled(!canSubmit || isWorking)
                    Button("Create account") { Task { await signUp() } }
                        .disabled(!canSubmit || isWorking)
                }
                Section {
                    Text("Ratings and dishes need an account. The app does not use another sign-in method, so Sign in with Apple is not required.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Account")
        .alert("Account", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .confirmationDialog("Delete your account and ratings?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    private func signIn() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await Backend.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            await model.refreshSession()
            password = ""
        } catch {
            message = error.localizedDescription
        }
    }

    private func signUp() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let ready = try await Backend.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            await model.refreshSession()
            password = ""
            if !ready && !model.isSignedIn {
                message = "We sent a confirmation email. Sign in after you confirm it."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func signOut() async {
        do {
            try await Backend.signOut()
            await model.refreshSession()
        } catch {
            message = error.localizedDescription
        }
    }

    private func deleteAccount() async {
        do {
            try await Backend.deleteAccount()
            await model.refreshSession()
            message = "The account was deleted."
        } catch {
            message = error.localizedDescription
        }
    }
}
