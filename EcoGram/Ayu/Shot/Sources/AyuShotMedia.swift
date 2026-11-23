import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext

private let ayuShotMediaTimeout: Double = 15.0

private struct AyuShotMediaResource {
    let peerId: EnginePeer.Id
    let reference: MediaResourceReference
    let resource: EngineMediaResource
    let contentType: MediaResourceUserContentType
}

private func ayuShotMediaResources(_ message: EngineRawMessage) -> [AyuShotMediaResource] {
    let messageReference = MessageReference(message)
    var result: [AyuShotMediaResource] = []
    func append(_ media: EngineRawMedia, _ representations: [TelegramMediaImageRepresentation], _ contentType: MediaResourceUserContentType) {
        if let representation = largestImageRepresentation(representations) {
            result.append(AyuShotMediaResource(peerId: message.id.peerId, reference: AnyMediaReference.message(message: messageReference, media: media).resourceReference(representation.resource), resource: EngineMediaResource(representation.resource), contentType: contentType))
        }
    }
    for media in message.media {
        if let image = media as? TelegramMediaImage {
            append(image, image.representations, .image)
        } else if let file = media as? TelegramMediaFile {
            if file.isSticker || file.isAnimatedSticker || file.isCustomEmoji {
                result.append(AyuShotMediaResource(peerId: message.id.peerId, reference: AnyMediaReference.message(message: messageReference, media: file).resourceReference(file.resource), resource: EngineMediaResource(file.resource), contentType: .sticker))
            } else {
                append(file, file.previewRepresentations, MediaResourceUserContentType(file: file))
            }
        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, let image = content.image {
            append(image, image.representations, .image)
        }
    }
    return result
}

func ayuShotMediaReady(context: AccountContext, messages: [EngineMessage]) -> Signal<Void, NoError> {
    let resources = messages.flatMap { ayuShotMediaResources($0._asMessage()) }
    guard !resources.isEmpty else {
        return .single(Void())
    }
    return Signal { subscriber in
        let fetches = DisposableSet()
        for item in resources {
            fetches.add(context.engine.resources.fetch(reference: item.reference, userLocation: .peer(item.peerId), userContentType: item.contentType).startStrict())
        }
        let statuses = resources.map { item -> Signal<Bool, NoError> in
            return context.engine.resources.status(resource: item.resource)
            |> map { status -> Bool in
                if case .Local = status {
                    return true
                }
                return false
            }
        }
        let ready = (combineLatest(statuses)
        |> filter { values in
            return !values.contains(false)
        }
        |> take(1)
        |> map { _ -> Void in
            return Void()
        }
        |> timeout(ayuShotMediaTimeout, queue: Queue.mainQueue(), alternate: .single(Void()))
        |> deliverOnMainQueue).startStrict(next: { _ in
            subscriber.putNext(Void())
            subscriber.putCompletion()
        })
        return ActionDisposable {
            fetches.dispose()
            ready.dispose()
        }
    }
}
