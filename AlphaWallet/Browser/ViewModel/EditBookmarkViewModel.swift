// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

struct EditBookmarkViewModelInput {
    let saveSelected: AnyPublisher<(title: String, url: String), Never>
}

struct EditBookmarkViewModelOutput {
    let viewState: AnyPublisher<EditBookmarkViewModel.ViewState, Never>
    let bookmarkSaved: AnyPublisher<Void, Never>
}

class EditBookmarkViewModel {
    private let bookmark: Bookmark
    private let bookmarksStore: BookmarksStore

    init(bookmark: Bookmark, bookmarksStore: BookmarksStore) {
        self.bookmark = bookmark
        self.bookmarksStore = bookmarksStore
    }

    func transform(input: EditBookmarkViewModelInput) -> EditBookmarkViewModelOutput {
        let bookmark = Just(bookmark)
        let bookmarkSaved = input.saveSelected
            .handleEvents(receiveOutput: { [bookmarksStore] data in
                guard data.url.nonEmpty else { return }
                bookmarksStore.update(bookmark: self.bookmark, title: data.title, url: data.url)
            }).mapToVoid()
            .eraseToAnyPublisher()

        let viewState = bookmark.map { bookmark -> ViewState in
            let imageUrl = Favicon.get(for: URL(string: bookmark.url))
            return EditBookmarkViewModel.ViewState(title: bookmark.title, url: bookmark.url, imageUrl: imageUrl)
        }.eraseToAnyPublisher()

        return .init(viewState: viewState, bookmarkSaved: bookmarkSaved)
    }

    let backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground

    var imageShadowColor: UIColor {
        return Metrics.DappsHome.Icon.shadowColor
    }

    var imageShadowOffset: CGSize {
        return Metrics.DappsHome.Icon.shadowOffset
    }

    var imageShadowOpacity: Float {
        return Metrics.DappsHome.Icon.shadowOpacity
    }

    var imageShadowRadius: CGFloat {
        return Metrics.DappsHome.Icon.shadowRadius
    }

    var imageBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var imagePlaceholder: UIImage {
        return R.image.launch_icon()!
    }

    var screenTitle: String {
        return R.string.localizable.dappBrowserMyDappsEdit()
    }

    var titleText: String {
        return R.string.localizable.dappBrowserMyDappsEditTitleLabel()
    }

    var urlText: String {
        return R.string.localizable.dappBrowserMyDappsEditUrlLabel()
    }

    var saveButtonTitle: String {
        return R.string.localizable.save()
    }
}

extension EditBookmarkViewModel {

    struct ViewState {
        let title: String
        let url: String
        let imageUrl: URL?
    }
}
