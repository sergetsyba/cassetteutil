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
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0")
	],
	targets: [
		.executableTarget(
			name: "cassetteutil",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser")
			],
			path: "Sources/cassetteutil"),
		.target(
			name: "libcassetteio",
			dependencies: [],
			path: "Sources/libcassetteio")
	])
