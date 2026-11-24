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
                Section("Fiók") {
                    Text(model.userEmail ?? "Bejelentkezve")
                    if let country = model.favorite?.country {
                        Text("Kedvenc ország: \(country.name)")
                    }
                    if let place = model.favorite?.restaurant {
                        Text("Kedvenc hely: \(place.name), \(place.city)")
                    }
                    Button("Kijelentkezés") { Task { await signOut() } }
                    Button("Fiók törlése", role: .destructive) { confirmDelete = true }
                }
                Section("Adataid") {
                    Text("Az e-mail címed, az értékeléseid, az ételeid és a kedvenc országod meg éttermed a Supabase adatbázisban vannak, a fiókodhoz kötve. A helyzeted csak az útvonalhoz kell, és nem mentjük el.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Section("Belépés") {
                    TextField("E-mail", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Jelszó, legalább 6 karakter", text: $password)
                        .textContentType(.password)
                    Button(isWorking ? "Folyamatban…" : "Bejelentkezés") {
                        Task { await signIn() }
                    }
                    .disabled(!canSubmit || isWorking)
                    Button("Regisztráció") { Task { await signUp() } }
                        .disabled(!canSubmit || isWorking)
                }
                Section {
                    Text("Az értékeléshez és az ételekhez fiók kell. Más belépési módot az app nem használ, ezért a Sign in with Apple nem kötelező.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Fiók")
        .alert("Fiók", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("Rendben", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .confirmationDialog("Törlöd a fiókot és az értékeléseidet?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Fiók törlése", role: .destructive) { Task { await deleteAccount() } }
            Button("Mégse", role: .cancel) {}
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
                message = "Elküldtük a megerősítő e-mailt. Utána jelentkezz be."
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
            message = "A fiók törölve."
        } catch {
            message = error.localizedDescription
        }
    }
}
