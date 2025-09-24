//
//  ServiceLocator.swift
//  hmosdemos
//
import Foundation

final class ServiceLocator {
    static let shared = ServiceLocator()
    private init() {}

    let wearEngineManager = WearEngineManager()
}
