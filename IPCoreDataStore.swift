//
//  IPCoreDataStore.swift
//  InPos+CoreData
//
//  Created by Zsolt Balint on 12/8/16.
//  Copyright © 2016 InPos Soft. All rights reserved.
//

import CoreData

internal class IPCoreDataStore: NSObject {

	// MARK: -
	// MARK: Properties

	private var databaseName: String!

	// MARK: -
	// MARK: Initialization

	internal init(databaseName: String, andInitialDatabaseName initialDatabaseName: String!) {
		super.init()

		self.databaseName = databaseName

		let storeURL = URL.applicationDocumentsDirectory().appendingPathComponent(initialDatabaseName != nil ? initialDatabaseName : databaseName + ".sqlite")
		if initialDatabaseName != nil && !FileManager.default.fileExists(atPath: storeURL.path) {
			let initialDatabaseExtension = (initialDatabaseName as NSString).pathExtension
			let initialDatabaseFileName = (initialDatabaseName as NSString).deletingPathExtension

			do {
				try FileManager.default.copyItem(at: Bundle.main.url(forResource: initialDatabaseFileName, withExtension: initialDatabaseExtension)!, to: storeURL)
			} catch {
			}
		}
	}

	// MARK: -
	// MARK: Getters and setters

	internal lazy var managedObjectModel: NSManagedObjectModel = {
		// The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
		let modelURL = Bundle.main.url(forResource: self.databaseName, withExtension: "momd")!
		return NSManagedObjectModel(contentsOf: modelURL)!
	}()

	internal lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
		// The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
		// Create the coordinator and store
		let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
		let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
		let url = URL.applicationDocumentsDirectory().appendingPathComponent(self.databaseName + ".sqlite")
		var failureReason = "There was an error creating or loading the application's saved data."

		do {
			try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
		} catch let error as NSError {
			// Report any error we got.
			var dict = [String: AnyObject]()
			dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
			dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?

			dict[NSUnderlyingErrorKey] = error
			let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
			// Replace this with code to handle the error appropriately.
			// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
			NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
			abort()
		} catch {
			// Should never reach to this point
		}

		return coordinator
	}()
}
