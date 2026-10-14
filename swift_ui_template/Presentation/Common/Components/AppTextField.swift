import SwiftUI
import UIKit

struct AppTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var isSecure = false
    var error: String?

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Group {
                    if isSecure && !isRevealed {
                        SecureField(title, text: $text)
                    } else {
                        TextField(title, text: $text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(isRevealed ? Text("Hide password") : Text("Show password"))
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.Radius.m))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .stroke(error == nil ? Color.clear : Color.red, lineWidth: 1)
            }

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.m) {
        AppTextField(title: "Username", text: .constant("emilys"))
        AppTextField(title: "Password", text: .constant(""), isSecure: true, error: "This field is required.")
    }
    .padding()
}
