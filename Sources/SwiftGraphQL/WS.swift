import Foundation
import GraphQL

#if canImport(GraphQLWebSocket)
    import RxSwift
    import GraphQLWebSocket

    public extension GraphQLWebSocket {
        /// Subscribes to a subscription using SwiftGraphQL selection and returns a publisher
        /// emitting decoded received results.
        ///
        /// ```
        /// let endpoint = URL(string: "ws://mygraphql.com/graphql")!
        /// let client = GraphQLWebSocket(request: URLRequest(url: endpoint))
        ///
        /// let subscription = Selection.Subscription<String> { try $0.hello() }
        ///
        /// client.subscribe(subscription)
        ///     .sink { completion in
        ///         print(completion)
        ///     } receiveValue: { (result: String) in
        ///         print(result)
        ///     }
        /// ```
        func subscribe<T, TypeLock>(
            _ selection: Selection<T, TypeLock>,
            as operationName: String? = nil,
            extensions: [String: AnyCodable]? = nil,
            decoder _: JSONDecoder = JSONDecoder()
        ) -> Observable<DecodedExecutionResult<T>> where TypeLock: GraphQLWebSocketOperation {
            let args = selection.encode(operationName: operationName, extensions: extensions)

            let publisher = subscribe(args)
                .map { result -> DecodedExecutionResult<T> in
                    let data = try selection.decode(raw: result.data)
                    let result = DecodedExecutionResult<T>(
                        data: data,
                        errors: result.errors,
                        hasNext: result.hasNext,
                        extensions: result.extensions
                    )

                    return result
                }

            return publisher
        }
    }
#endif
