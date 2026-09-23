import Foundation

/// What the card's URL field can hand to EventKit — and what it has to turn
/// down.
///
/// A rule of its own so the field and the write agree by construction. They
/// did not: the store decided what was storable at save time, the field knew
/// nothing about it, and text it could not store simply disappeared when the
/// card closed. On this board losing what somebody typed is the worst class of
/// bug there is — a missing word boundary in `StatusTagger` once destroyed a
/// user's own note the same way — so the field now asks the same question
/// while it is still being typed into.
enum TicketURL {

    /// The address to store, or nil when the text is not one.
    ///
    /// `URL(string:)` is permissive enough for the way people actually write
    /// addresses — "example.com" parses and round-trips unchanged, so a scheme
    /// is not forced onto text the user did not write one into.
    ///
    /// The whitespace check is the part that has to be done by hand. It used
    /// to be true that prose "does not parse and therefore is not stored" —
    /// that stopped being true in macOS 14, where `URL(string:)`
    /// percent-encodes invalid characters by default. So "Notiz mit
    /// Leerzeichen" was quietly filed as an address and read back as
    /// "Notiz%20mit%20Leerzeichen": the user's own words, mangled, in a field
    /// they could no longer recognise. A space is the one thing no address
    /// contains, and prose always has one.
    ///
    /// What passes may still be normalised — "https://münchen.de" is stored as
    /// its punycode form and reads back that way. That is a correct,
    /// resolvable address rather than a mangled sentence, so it is kept;
    /// rejecting it (`encodingInvalidCharacters: false` returns nil for the
    /// whole umlaut family) would throw away real links to avoid an unusual
    /// spelling.
    static func parsed(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: \.isWhitespace) else { return nil }
        return URL(string: trimmed)
    }

    /// True while the field holds something that will not be kept.
    ///
    /// An empty field is deliberately not a complaint: clearing the address is
    /// a normal edit, and a field that objects to being empty would be
    /// objecting to the user's own decision.
    static func rejects(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsed(text) == nil
    }
}
