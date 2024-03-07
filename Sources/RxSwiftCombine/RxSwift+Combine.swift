import RxSwift


public extension Disposable {
    func store(in collection: inout Set<DisposeBag>) {
        let bag = DisposeBag()
        collection.insert(bag)
        self.disposed(by: bag)
    }

    func cancel() {
        dispose()
    }
}

public extension Observable {

    func sink(
        receiveCompletion onCompleted: ((()) -> Void)? = nil,
        receiveValue onNext: @escaping (Element) -> Void
    ) -> Disposable {
        self.subscribe(onNext: onNext, onCompleted: { onCompleted?(()) })
    }

    func sink(
        receiveCompletion onCompleted: ((()) -> Void)? = nil,
        receiveValue onNext: @escaping (Element) -> Void
    ) -> DisposeBag {
        let bag = DisposeBag()
        self.subscribe(onNext: onNext, onCompleted: { onCompleted?(()) })
            .disposed(by: bag)
        return bag
    }

    public func handleEvents(
        receiveSubscription: ((()) -> Void)? = nil,
        receiveOutput: ((Element) -> Void)? = nil,
        receiveCompletion: ((()) -> Void)? = nil,
        receiveCancel: (() -> Void)? = nil
//        receiveRequest: ((Subscribers.Demand) -> Void)? = nil
    ) -> Observable<Element> {
        self.do(
            onNext: receiveOutput,
            onCompleted: { receiveCompletion?(()) },
            onSubscribe: { receiveSubscription?(()) },
            onDispose: receiveCancel
        )
    }

    public func tryMap<T>(_ transform: @escaping (Element) throws -> T) -> Observable<T> {
        self.map(transform)
    }

    func merge(with other: Observable<Element>) -> Observable<Element> {
        Observable.merge(self, other)
    }
}

public extension PublishSubject {
    func send(_ element: Element) {
        onNext(element)
    }

    enum Completion {
        /// The subject finished normally.
        case finished
    }

    func send(completion: Completion) {
        switch completion {
            case .finished:
                onCompleted()
        }
    }
}

public extension Observable {
    func first() async throws -> Element {
        try await take(1).asSingle().value
    }
}


extension DisposeBag: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension DisposeBag: Equatable {
    public static func ==(_ lhs: DisposeBag, _ rhs: DisposeBag) -> Bool { lhs === rhs }
}
