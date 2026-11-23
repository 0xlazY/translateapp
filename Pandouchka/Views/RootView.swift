import SwiftUI

enum AppTab: Hashable {
    case today, stories, cards, dictionary
}

/// Shared navigation state so screens can jump to each other (e.g. "Review now").
@MainActor
final class AppRouter: ObservableObject {
    @Published var tab: AppTab = .today
    @Published var reviewing = false
}

struct RootView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var translator = Translator.shared

    var body: some View {
        TabView(selection: $router.tab) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView()
            }
            Tab("Stories", systemImage: "book.pages", value: AppTab.stories) {
                StoriesView()
            }
            Tab("Cards", systemImage: "rectangle.stack", value: AppTab.cards) {
                CardsView()
            }
            Tab("Dictionary", systemImage: "character.book.closed", value: AppTab.dictionary) {
                DictionaryView()
            }
        }
        .tint(Palette.blue)
        .environmentObject(router)
        .modifier(TranslationHost(translator: translator))
        .fullScreenCover(isPresented: $router.reviewing) {
            ReviewView()
        }
    }
}
