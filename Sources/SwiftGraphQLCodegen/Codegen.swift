import Foundation
//import SwiftFormat
//import SwiftFormatConfiguration


public struct GraphQLCodegen {
    /// Generates a target GraphQL Swift file.
    ///
    /// - Parameters:
    ///     - target: Target output file path.
    ///     - from: GraphQL server endpoint.
    ///     - onComplete: A function triggered once the generation finishes.
    public static func generate(
        _ target: URL,
        from schemaURL: URL,
        onComplete: @escaping () -> Void = {}
    ) -> Void {
        /* Delegates to the sub function. */
        self.generate(from: schemaURL) { code in
            /* Write the code to the file system. */
            let targetDir = target.deletingLastPathComponent()
            try! FileManager.default.createDirectory(
                at: targetDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try! code.write(to: target, atomically: true, encoding: .utf8)
            
            onComplete()
        }
    }
    
    /// Generates the API and returns it to handler.
    public static func generate(from schemaURL: URL, handler: @escaping (String) -> Void) -> Void {
        /* Code generator function. */
        func generator(schema: GraphQL.Schema) -> Void {
            let code = self.generate(from: schema)
            handler(code)
        }
        
        /* Download the schema from endpoint. */
        self.downloadFrom(schemaURL, handler: generator)
    }
    
    
    /* Internals */
    
    
    /// Generates the code that can be used to define selections.
    private static func generate(from schema: GraphQL.Schema) -> String {
        /* Data */
        
        let operations: [(name: String, type: GraphQL.FullType)] = [
            ("RootQuery", schema.queryType.name),
            ("RootMutation",schema.mutationType?.name),
            ("RootSubscription",schema.subscriptionType?.name)
        ].compactMap { (name, operation) in
            schema.types.first(where: { $0.name == operation }).map { (name, $0) }
        }
        
        let objects: [(name: String, type: GraphQL.FullType)] = schema.objects.map {
            (name: generateObjectType(for: $0.name), type: $0)
        }
        
        /* Generate the API. */
        let code = """
            import SwiftGraphQL

            // MARK: - Operations
            
            \(operations.map { generateObject($0.name, for: $0.type) }.lines)

            // MARK: - Objects

            \(generatePhantomTypes(for: schema.objects))

            // MARK: - Selection

            \(objects.map { generateObject($0.name, for: $0.type) }.lines)

            // MARK: - Enums

            \(schema.enums.map { generateEnum($0) }.lines)
            """
        
        return code
        
//        /* Format the code. */
//        var parsed: String = ""
//
//        let configuration = Configuration()
//        let formatted = SwiftFormatter(configuration: configuration)
//
//        try! formatted.format(source: code, assumingFileURL: nil, to: &parsed)
//
//        /* Return */
//
//        return parsed
    }
    

    /* Objects */
    
    /// Generates an object phantom type entry.
    private static func generatePhantomTypes(for types: [GraphQL.FullType]) -> String {
        """
        enum Object {
        \(types.map { generatePhantomType(for: $0) }.lines)
        }
        
        \(types.map { generatePhantomTypeAlias(for: $0)}.lines)
        """
    }
    
    private static func generatePhantomType(for type: GraphQL.FullType) -> String {
        """
            enum \(type.name) {}
        """
    }
    
    private static func generatePhantomTypeAlias(for type: GraphQL.FullType) -> String {
        "typealias \(type.name)Object = Object.\(type.name)"
    }
    
    /// Generates an object type used for aliasing a phantom type.
    private static func generateObjectType(for typeName: String) -> String {
        "\(typeName)Object"
    }

    /// Generates a function to handle a type.
    private static func generateObject(_ typeName: String, for type: GraphQL.FullType) -> String {
        // TODO: add support for all fields!
        let fields = (type.fields ?? []).filter {
            switch $0.type.namedType { // TODO
            case .scalar(let scalar):
                return !scalar.isCustom
            case .object(_), .enumeration(_):
                return true
            default:
                return false
            }
        }
        
        return """
        /* \(type.name) */

        extension SelectionSet where TypeLock == \(typeName) {
        \(fields.map(generateObjectField).lines)
        }
        """
    }

    private static func generateObjectField(_ field: GraphQL.Field) -> String {
        /* Code Parts */
        let description = "/// \(field.description ?? "")"
        let fnDefinition = generateFnDefinition(for: field)
        let returnType = generateReturnType(for: field.type)
        
        let fieldLeaf = generateFieldLeaf(for: field)
        let decoder = generateDecoder(for: field)
        let mockData = generateMockData(for: field.type)
        
        return """
            \(description)
            func \(fnDefinition) -> \(returnType) {
                let field = \(fieldLeaf)

                // selection
                self.select(field)

                // decoder
                if let data = self.response {
                   return \(decoder)
                }

                // mock placeholder
                return \(mockData)
            }
        """
    }
    
    /// Generates a function definition for a field.
    private static func generateFnDefinition(for field: GraphQL.Field) -> String {
        switch field.type.namedType {
        case .scalar(_), .enumeration(_):
            return "\(field.name)()"
        case .inputObject(_),
             .interface(_),
             .object(_),
             .union(_):
            let typeLock = generateObjectType(for: field.type.namedType.name)
            let decoderType = generateDecoderType(typeLock, for: field.type)
            return "\(field.name)<Type>(_ selection: Selection<Type, \(decoderType)>)"
        }
    }
    
    /// Recursively generates a return type of a referrable type.
    private static func generateReturnType(for ref: GraphQL.TypeRef) -> String {
        switch ref.namedType {
        case .scalar(let scalar):
            let scalarType = generateReturnType(for: scalar)
            return generateDecoderType(scalarType, for: ref)
        case .enumeration(let enm):
            return generateDecoderType(enm, for: ref)
        case .inputObject(_),
             .interface(_),
             .object(_),
             .union(_):
            return "Type"
        }
    }
    

    /// Translates a scalar abstraction into Swift-compatible type.
    ///
    /// - Note: Every type is optional by default since we are comming from GraphQL world.
    private static func generateReturnType(for scalar: GraphQL.Scalar) -> String {
        switch scalar {
        case .boolean:
            return "Bool"
        case .float:
            return "Double"
        case .integer:
            return "Int"
        case .string, .id:
            return "String"
        case .custom(let type):
            return "\(type)"
        }
    }
    
    /// Generates an internal leaf definition used for composing selection set.
    private static func generateFieldLeaf(for field: GraphQL.Field) -> String {
        switch field.type.namedType {
        case .scalar(_), .enumeration(_):
            return "GraphQLField.leaf(name: \"\(field.name)\")"
        case .inputObject(_), .interface(_), .object(_), .union(_):
            return "GraphQLField.composite(name: \"\(field.name)\", selection: selection.selection)"
        }
        
    }
    
    /// Generates a field decoder.
    private static func generateDecoder(for field: GraphQL.Field) -> String {
        switch field.type.namedType {
        case .scalar(_):
            let returnType = generateReturnType(for: field.type)
            return "(data as! [String: Any])[field.name] as! \(returnType)"
        case .enumeration(let enm):
            let decoderType = generateDecoderType("String", for: field.type)
            if decoderType == "String" {
                return "\(enm).init(rawValue: (data as! [String: Any])[field.name] as! String)!"
            }
            return "((data as! [String: Any])[field.name] as! \(decoderType)).map { \(enm).init(rawValue: $0)! }"
        case .inputObject(_), .interface(_), .object(_), .union(_):
            let decoderType = generateDecoderType("Any", for: field.type)
            return "selection.decode(data: ((data as! [String: Any])[field.name] as! \(decoderType)))"
        }
        /**
         We might need `list` and `null` selection set since the above nesting may be arbitratily deep.
            People may use a nested nested list, for example, and schema allows for that. The problem lays in the
            current decoders.
         */
    }
    
    /// Generates an intermediate type used in custom decoders to cast JSON representation of the data.
    private static func generateDecoderType(_ typeName: String, for type: GraphQL.TypeRef) -> String {
        switch type {
        case .named(_):
            return "\(typeName)?"
        /* Wrapped types */
        case .list(let subRef):
            return "[\(generateDecoderType(typeName, for: subRef))]?"
        case .nonNull(let subRef):
            // everything is nullable by default, that's why
            // we are removing question mark
            var nullable = generateDecoderType(typeName, for: subRef)
            nullable.remove(at: nullable.index(before: nullable.endIndex))
            return nullable
        }
    }
    
    /// Generates value placeholders for the API.
    private static func generateMockData(for ref: GraphQL.TypeRef) -> String {
        switch ref {
        /* Named Types */
        case let .named(named):
            switch named {
            case .scalar(let scalar):
                return generateMockData(for: scalar)
            case .enumeration(let enm):
                return "\(enm).allCases.first!"
            default:
                return "selection.mock()"
            }
        /* Wrappers */
        case .list(_):
            return "selection.mock()"
        case .nonNull(let subRef):
            return generateMockData(for: subRef)
        }
    }
    
    /// Generates mock data for an abstract scalar type.
    private static func generateMockData(for scalar: GraphQL.Scalar) -> String {
        switch scalar {
        case .id:
            return "\"8378\""
        case .boolean:
            return "true"
        case .float:
            return "3.14"
        case .integer:
            return "42"
        case .string:
            return "\"Matic Zavadlal\""
        case .custom(_): // TODO!
            return ""
        }
    }
    
    /* Enums */

    /// Generates an enumeration code.
    private static func generateEnum(_ type: GraphQL.FullType) -> String {
        let cases = type.enumValues ?? []
        return """
        enum \(type.name): String, CaseIterable, Codable {
        \(cases.map(generateEnumCase).lines)
        }
        """
    }

    private static func generateEnumCase(_ env: GraphQL.EnumValue) -> String {
        """
            case \(env.name) = \"\(env.name)\"
        """
    }
    
    /* Schema Downloader */
    
    /// Downloads a schema from the provided endpoint to the target file path.
    ///
    /// - Parameters:
    ///     - endpoint: The URL of your GraphQL server.
    ///     - handler: Introspection schema handler.
    public static func downloadFrom(_ endpoint: URL, handler: @escaping (GraphQL.Schema) -> Void) {
        self.downloadFrom(endpoint) { (data: Data) -> Void in handler(GraphQL.parse(data)) }
    }
    
    
    /// Downloads a schema from the provided endpoint to the target file path.
    ///
    /// - Parameters:
    ///     - endpoint: The URL of your GraphQL server.
    ///     - handler: Introspection schema handler.
    public static func downloadFrom(_ endpoint: URL, handler: @escaping (Data) -> Void) -> Void {
        /* Compose a request. */
        var request = URLRequest(url: endpoint)
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        
        let query: [String: Any] = ["query": GraphQL.introspectionQuery]
        
        request.httpBody = try! JSONSerialization.data(
            withJSONObject: query,
            options: JSONSerialization.WritingOptions()
        )
        
        /* Load the schema. */
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            /* Check for errors. */
            if let _ = error {
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return
            }
            
            /* Save JSON to file. */
            if let data = data {
                handler(data)
            }
        }
        
        task.resume()
    }

}

