// Copyright (c) 2024 PassiveLogic, Inc.

import class Foundation.Process
import struct Foundation.URL
import PackagePlugin

@main
struct Generator: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let pluginPath = context.package.directory.appending(["CLI"])
        let path = try context.tool(named: "swift").path.string
        let url = URL(fileURLWithPath: path)

        let process = Process()
        process.executableURL = url
        process.arguments = [
            "package",
            "--package-path", pluginPath.string,
            "--manifest-cache", "local",
            "--disable-sandbox",
            "swift-graphql-cli",
        ] + arguments

        try process.run()
        process.waitUntilExit()
    }
}
