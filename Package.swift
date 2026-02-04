//
//  Package.swift
//  CassetteUtility
//
//  Created by Serge Tsyba on 3.1.2026.
//

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "CassetteUtility",
	platforms: [
		.macOS(.v13)
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0")
	],
	targets: [
		.executableTarget(
			name: "CassetteUtility",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				"libcassetteio"
			],
			path: "Sources/CassetteUtility"),
		.testTarget(
			name: "CassetteUtilityTests",
			dependencies: ["CassetteUtility"],
			path: "Tests/CassetteUtilityTests",
			resources: [
				.process("Resources")
			]),
		.target(
			name: "libcassetteio",
			path: "Sources/libcassetteio",
			linkerSettings: [
				.linkedFramework("CoreAudio")
			])
	])
