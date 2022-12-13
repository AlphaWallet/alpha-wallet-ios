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
    private let bookmark: BookmarkObject
    private let bookmarksStore: BookmarksStore

    init(bookmark: BookmarkObject, bookmarksStore: BookmarksStore) {
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
            let imageUrl = Favicon.get(for: bookmark.url)
            return EditBookmarkViewModel.ViewState(bookmarkTitle: bookmark.title, bookmarkUrl: bookmark.url?.absoluteString ?? "", imageUrl: imageUrl)
        }.eraseToAnyPublisher()

        return .init(viewState: viewState, bookmarkSaved: bookmarkSaved)
    }

    var imageShadowColor: UIColor {
        return DataEntry.Metric.DappsHome.Icon.shadowColor
    }

    var imageShadowOffset: CGSize {
        return DataEntry.Metric.DappsHome.Icon.shadowOffset
    }

    var imageShadowOpacity: Float {
        return DataEntry.Metric.DappsHome.Icon.shadowOpacity
    }

    var imageShadowRadius: CGFloat {
        return DataEntry.Metric.DappsHome.Icon.shadowRadius
    }

    var imageBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var imagePlaceholder: UIImage {
        return R.image.launch_icon()!
    }

    var titleText: String {
        return R.string.localizable.dappBrowserMyDappsEditTitleLabel()
    }

    var urlText: String {
        return R.string.localizable.dappBrowserMyDappsEditUrlLabel()
    }

}

extension EditBookmarkViewModel {

    struct ViewState {
        let title: String = R.string.localizable.dappBrowserMyDappsEdit()
        let bookmarkTitle: String
        let bookmarkUrl: String
        let imageUrl: URL?
    }
}
