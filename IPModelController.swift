//
//  IPModelController.swift
//  InPos+CoreData
//
//  Created by Zsolt Balint on 12/8/16.
//  Copyright © 2016 InPos Soft. All rights reserved.
//

import Foundation
import CoreData

public enum IPModelControllerNotification {
	static let kFoundCurrentUserNotification = "com.inpos.modelController.kFoundCurrentUserNotification"
	static let kToken = "com.inpos.modelController.kToken"
}

open class IPModelController: NSObject {

	// MARK: -
	// MARK: Properties

	private(set) public var coreDataController: IPCoreDataController!

	// MARK: -
	// MARK: Initialization

	public override init() {
		super.init()

		coreDataController = IPCoreDataController()
	}

	public init(databaseName: String!) {
		super.init()

		coreDataController = IPCoreDataController(name: databaseName)
	}

	public init(databaseName: String!, andInitialDatabaseName initialDatabaseName: String!) {
		super.init()

		coreDataController = IPCoreDataController(name: databaseName, initialName: initialDatabaseName)
	}

	// MARK: -
	// MARK: Public methods
    
    open func setContexts(_ privateQueueContext: NSManagedObjectContext, mainQueueContext: NSManagedObjectContext? = nil, supplementaryContext: NSManagedObjectContext? = nil) {
        coreDataController.setContexts(privateQueueContext, mainQueueContext: mainQueueContext, supplementaryContext: supplementaryContext)
    }
    
    open func setUpSupplementaryContextAs(childContext: Bool, context: NSManagedObjectContext? = nil) {
        
        // Context will be created with mainQueueConcurrencyType if context is nil
        coreDataController.setUpSupplementaryContextAs(childContext: childContext, context: context)
    }
    
    open func insertedObject(for entityType: NSManagedObject.Type, contextType: ManageObjectContextType = .main) -> NSManagedObject? {
        guard let entityName = self.entityName(for: entityType) else {
            return nil
        }
        return coreDataController.insertedObjectForEntityName(entityName, contextType: .main)
    }
    
    open func objectsForFetchRequest(_ fetchRequest: NSFetchRequest<NSManagedObject>, contextType: ManageObjectContextType = .main) -> [NSManagedObject]? {
        return coreDataController.objectsForFetchRequest(fetchRequest, contextType: contextType)
    }
    
    open func firstObject(for entityType: NSManagedObject.Type, withPredicate predicate: NSPredicate? = nil, contextType: ManageObjectContextType = .main) -> NSManagedObject? {
        guard let entityName = self.entityName(for: entityType) else {
            return nil
        }
        return coreDataController.firstObjectForEntityName(entityName, withPredicate: predicate, contextType: contextType)
    }
    
    open func objects(for entityType: NSManagedObject.Type, withPredicate predicate: NSPredicate!, contextType: ManageObjectContextType = .main) -> [NSManagedObject]? {
        guard let entityName = self.entityName(for: entityType) else {
            return nil
        }
        return coreDataController.objectsForEntityName(entityName, withPredicate: predicate, contextType: contextType)
    }
    
    open func frc(for entityType: NSManagedObject.Type, andSortDescriptors sortDescriptors: Array<NSSortDescriptor>?, andSectionNameKeyPath sectionNameKeyPath: String?, andPredicate predicate: NSPredicate?, contextType: ManageObjectContextType = .main) -> NSFetchedResultsController<NSManagedObject>? {
        guard let entityName = self.entityName(for: entityType) else {
            return nil
        }
        return coreDataController.frc(forEntityName: entityName, andSortDescriptors: sortDescriptors, andSectionNameKeyPath: sectionNameKeyPath, andPredicate: predicate, contextType: contextType)
    }

	open func ownedObject<ManagedObjectType: NSManagedObject>(_ object: ManagedObjectType) -> ManagedObjectType? {
		return coreDataController.objectToOwnContext(object) as? ManagedObjectType
	}

	open func save(contextType: ManageObjectContextType = .main) {
		coreDataController.save(contextType: contextType)
	}
    
    open func rollBack(contextType: ManageObjectContextType = .main) {
        coreDataController.rollBack(contextType: contextType)
    }
    
	open func deleteObject<ManagedObjectType: NSManagedObject>(_ object: ManagedObjectType, contextType: ManageObjectContextType? = nil) {
		coreDataController.deleteObject(object, contextType: contextType)
	}

    open func deleteAllFromPersistentStoreObjects(by entityType: NSManagedObject.Type, contextType: ManageObjectContextType = .main) {
        guard let entityName = self.entityName(for: entityType) else {
            return
        }
        self.coreDataController.deleteAllFromPersistentStoreObjectsBy(entityName: entityName, mergeContextType: contextType)
    }
    
    open func deleteObjects(for entityType: NSManagedObject.Type, withPredicate predicate: NSPredicate? = nil, fromContextType contextType: ManageObjectContextType = .main) {
        guard let entityName = self.entityName(for: entityType) else {
            return
        }
        self.coreDataController.deleteObjects(for: entityName, withPredicate: predicate, fromContextType: contextType)
    }
    
    // MARK: -
    // MARK: Private methods
    
    private func entityName(for entityType: NSManagedObject.Type) -> String? {
        guard let entityName = NSStringFromClass(entityType).components(separatedBy: ".").last else {
            print("Failed to retrieve EntityName for \(entityType)!")
            return nil
        }
        return entityName
    }
}
