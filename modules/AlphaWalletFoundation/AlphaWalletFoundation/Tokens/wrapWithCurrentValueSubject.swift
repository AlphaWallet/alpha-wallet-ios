import Combine

func wrapWithCurrentValueSubject<T>(_ subject: AnyPublisher<T, Never>, initialValue: T) -> CurrentValueSubject<T, Never> {
    let currentValueSubject = CurrentValueSubject<T, Never>(initialValue)

    //Careful because the cancellable is not stored
    _ = subject.sink { value in
        currentValueSubject.send(value)
    }

    return currentValueSubject
}
