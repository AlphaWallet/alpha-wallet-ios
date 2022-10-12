// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

struct EditBookmarkViewModelInput {
    let save: AnyPublisher<(title: String, url: String), Never>
}

struct EditBookmarkViewModelOutput {
    let viwState: AnyPublisher<EditBookmarkViewModel.ViewState, Never>
    let didSave: AnyPublisher<Void, Never>
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
        let didSave = input.save
            .handleEvents(receiveOutput: { [bookmarksStore] data in
                guard data.url.nonEmpty else { return }
                bookmarksStore.update(bookmark: self.bookmark, title: data.title, url: data.url)
            }).mapToVoid()
            .eraseToAnyPublisher()

        let viewState = bookmark.map { b -> ViewState in
            let imageUrl = Favicon.get(for: URL(string: b.url))
            return EditBookmarkViewModel.ViewState(title: b.title, url: b.url, imageUrl: imageUrl)
        }.eraseToAnyPublisher()

        return .init(viwState: viewState, didSave: didSave)
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

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

//    var imageUrl: URL? {
//        return Favicon.get(for: URL(string: dapp.url))
//    }

    var screenTitle: String {
        return R.string.localizable.dappBrowserMyDappsEdit()
    }

    var screenFont: UIFont {
        return Fonts.semibold(size: 20)
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
