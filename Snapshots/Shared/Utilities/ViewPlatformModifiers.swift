import SwiftUI

extension View {
    @ViewBuilder
    func platformInlineNavigationTitleDisplayMode() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }

    @ViewBuilder
    func platformLargeNavigationTitleDisplayMode() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
#else
        self
#endif
    }

    @ViewBuilder
    func platformLargePresentationDetent() -> some View {
#if os(iOS)
        self.presentationDetents([.large])
#else
        self
#endif
    }

    @ViewBuilder
    func platformNameTextInput() -> some View {
#if os(iOS)
        self
            .textContentType(.name)
            .autocapitalization(.words)
#else
        self
#endif
    }

    @ViewBuilder
    func platformEmailTextInput() -> some View {
#if os(iOS)
        self
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocapitalization(.none)
#else
        self
#endif
    }

    @ViewBuilder
    func platformURLTextInput() -> some View {
#if os(iOS)
        self
            .keyboardType(.URL)
            .autocapitalization(.none)
#else
        self
#endif
    }

    @ViewBuilder
    func platformNoAutocapitalization() -> some View {
#if os(iOS)
        self.autocapitalization(.none)
#else
        self
#endif
    }

    @ViewBuilder
    func platformNumberPadKeyboard() -> some View {
#if os(iOS)
        self.keyboardType(.numberPad)
#else
        self
#endif
    }

    @ViewBuilder
    func platformPhonePadKeyboard() -> some View {
#if os(iOS)
        self.keyboardType(.phonePad)
#else
        self
#endif
    }

    @ViewBuilder
    func platformStreetAddressLine1TextContentType() -> some View {
#if os(iOS)
        self.textContentType(.streetAddressLine1)
#else
        self
#endif
    }

    @ViewBuilder
    func platformStreetAddressLine2TextContentType() -> some View {
#if os(iOS)
        self.textContentType(.streetAddressLine2)
#else
        self
#endif
    }

    @ViewBuilder
    func platformAddressCityTextContentType() -> some View {
#if os(iOS)
        self.textContentType(.addressCity)
#else
        self
#endif
    }

    @ViewBuilder
    func platformAddressStateTextContentType() -> some View {
#if os(iOS)
        self.textContentType(.addressState)
#else
        self
#endif
    }

    @ViewBuilder
    func platformPostalCodeTextContentType() -> some View {
#if os(iOS)
        self.textContentType(.postalCode)
#else
        self
#endif
    }

    @ViewBuilder
    func platformSubmitLabelNext() -> some View {
#if os(iOS)
        self.submitLabel(.next)
#else
        self
#endif
    }

    @ViewBuilder
    func platformSubmitLabelDone() -> some View {
#if os(iOS)
        self.submitLabel(.done)
#else
        self
#endif
    }
}
