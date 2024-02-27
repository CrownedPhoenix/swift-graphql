// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CLI",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products can be used to vend plugins, making them visible to other packages.
        .plugin(
            name: "CLI",
            targets: ["CLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/JohnSundell/Files", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-format", "508.0.0" ..< "510.0.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/dominicegginton/Spinner", from: "2.0.0"),
        .package(name: "swift-graphql", path: "../"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "GraphQLAST", dependencies: [], path: "Sources/GraphQLAST"),
        .target(
            name: "SwiftGraphQLCodegen",
            dependencies: [
                "GraphQLAST",
                .product(name: "SwiftFormat", package: "swift-format"),
                .product(name: "SwiftFormatConfiguration", package: "swift-format"),
                .product(name: "SwiftGraphQLUtils", package: "swift-graphql"),
            ]
        ),

        .testTarget(
            name: "GraphQLASTTests",
            dependencies: [
                "GraphQLAST",
            ]
        ),
        .testTarget(
            name: "SwiftGraphQLCodegenTests",
            dependencies: [
                .product(name: "GraphQL", package: "swift-graphql"),
                "GraphQLAST",
                "SwiftGraphQLCodegen",
                .product(name: "SwiftGraphQL", package: "swift-graphql"),
            ],
            exclude: [
                "Integration/schema.json",
                "Integration/swiftgraphql.yml",
            ]
        ),

        // Executables

        .executableTarget(
            name: "Executable",
            dependencies: [
                .product(name: "Files", package: "Files"),
                .product(name: "Spinner", package: "Spinner"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftGraphQLCodegen",
            ],
            path: "Plugins/SwiftGraphQLCLI/Executable"
        ),
        .plugin(
            name: "CLI",
            capability: .command(intent: .custom(
                verb: "swift-graphql",
                description: "prints hello world"
            )),
            dependencies: [
                "Executable",
            ],
            path: "Plugins/SwiftGraphQLCLI/Plugin"
        ),
    ]
)
