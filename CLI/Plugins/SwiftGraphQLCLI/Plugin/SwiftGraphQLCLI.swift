// Copyright (c) 2024 PassiveLogic, Inc.

import class Foundation.Process
import struct Foundation.URL
import PackagePlugin

@main
struct Generator: CommandPlugin {
    func performCommand(context: PluginContext, arguments _: [String]) async throws {
        // Because we can't depend on third party packages
        // directly in a plugin, we instead route
        // all our plugin arguments to an executable
        // that *does* have access to third party packages.

        // We can look up tools (an executable) available
        // in the context of the package.
        let path = try context.tool(named: "SwiftGraphQLCLIExecutable").path
        let url = URL(fileURLWithPath: path.string)

        let process = Process()
        process.executableURL = url
        process.arguments = [context.package.directory.string]

        try process.run()
        process.waitUntilExit()
    }
}
