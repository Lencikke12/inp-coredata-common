//
//  IPCoreDataController.swift
//  InPos+CoreData
//
//  Created by Zsolt Balint on 12/8/16.
//  Copyright © 2016 InPos Soft. All rights reserved.
//

import CoreData

public enum ManageObjectContextType: Int {
    case main
    case supplementary
}

open class IPCoreDataController: NSObject {

	// MARK: -
	// MARK: Properties

	private var coreDataStore: IPCoreDataStore!
    
    // Private queue context
    // Should never be used to represent objects on the UI
    private var persistentStoreContext: NSManagedObjectContext!
        

    // Main queue context
    // Should be the primary context used to represent objects on the UI
    private lazy var mainQueueContext: NSManagedObjectContext! = {
        persistentStoreContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        persistentStoreContext.persistentStoreCoordinator = self.coreDataStore.persistentStoreCoordinator
        persistentStoreContext.name = "PersistentStoreContext"
        
        let mainQueueContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainQueueContext.name = "MainQueueContext"
        mainQueueContext.parent = persistentStoreContext

        if #available(iOS 10.0, *) {
            mainQueueContext.automaticallyMergesChangesFromParent = true
        }
        return mainQueueContext
    }()
    internal var supplementaryContext: NSManagedObjectContext! {
        didSet {
            if supplementaryContext == nil {
                return
            }
            supplementaryContext.name = "SupplementaryContext"
            
            if #available(iOS 10.0, *) {
                supplementaryContext.automaticallyMergesChangesFromParent = true
            }
        }
    }

	// MARK: -
	// MARK: Initialization

	public convenience override init() {
		guard let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? NSString else {
			abort()
		}
		self.init(name: bundleName.lowercased, initialName: nil)
	}

	public convenience init(name: String) {
		self.init(name: name, initialName: nil)
	}

	public init(name: String, initialName: String!) {
		super.init()

		self.coreDataStore = IPCoreDataStore(databaseName: name, andInitialDatabaseName: initialName)
	}

	// MARK: -
	// MARK: Public methods
    
    internal func setContexts(_ privateQueueContext: NSManagedObjectContext, mainQueueContext: NSManagedObjectContext? = nil, supplementaryContext: NSManagedObjectContext? = nil) {
        
        // Use this method if specific contexts ought to be used in the project
        self.persistentStoreContext = privateQueueContext
        self.mainQueueContext = mainQueueContext
        self.supplementaryContext = supplementaryContext
    }
    
    internal func setUpSupplementaryContextAs(childContext: Bool, context: NSManagedObjectContext? = nil) {
        
        // Create context if not instatiated yet
        if self.supplementaryContext == nil {
            self.supplementaryContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        }
        
        // Set up context as child or sibling of mainQueueContext
        self.supplementaryContext.parent = childContext ? mainQueueContext : persistentStoreContext
    }

	internal func insertedObjectForEntityName(_ entityName: String, contextType: ManageObjectContextType = .main) -> NSManagedObject {
        
        // Insert an object of given type to selected context
        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: managedObjectContext(for: contextType))
	}

	internal func objectsForFetchRequest(_ fetchRequest: NSFetchRequest<NSManagedObject>, contextType: ManageObjectContextType = .main) -> [NSManagedObject]? {
        
        // Return objects for fetch request from selected context
		var fetchResults: [NSManagedObject]?
		managedObjectContext(for: contextType).performAndWait { () -> Void in
			do {
				guard let results = try managedObjectContext(for: contextType).fetch(fetchRequest) as [NSManagedObject]? else {
					fetchResults = nil
					return
				}
				fetchResults = results
			} catch {
				fetchResults = nil
			}
		}

		return fetchResults
	}

	internal func firstObjectForEntityName(_ entityName: String, withPredicate predicate: NSPredicate? = nil, contextType: ManageObjectContextType = .main) -> NSManagedObject? {
        
        // First object for entityName filtered by predicate
		let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
		request.predicate = predicate

		guard let firstObject = objectsForFetchRequest(request, contextType: contextType)?.first else {
			return nil
		}
		return firstObject
	}

	internal func objectsForEntityName(_ entityName: String, withPredicate predicate: NSPredicate!, contextType: ManageObjectContextType = .main) -> [NSManagedObject]? {
        
        // Objects for entityName filtered by predicate
		let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
		request.predicate = predicate

		guard let fetchResults = objectsForFetchRequest(request, contextType: contextType) else {
			return nil
		}

		if fetchResults.count == 0 {
			return nil
		}

		return fetchResults
	}

	internal func objectToOwnContext(_ managedObject: NSManagedObject) -> NSManagedObject? {
        
        // Check if object exists in persistentStoreContext
		var resultObject: NSManagedObject? = nil
		do {
			resultObject = try persistentStoreContext.existingObject(with: managedObject.objectID)
		} catch {
		}
		return resultObject
	}

	internal func frc(forEntityName entityName: String, andSortDescriptors sortDescriptors: Array<NSSortDescriptor>?, andSectionNameKeyPath sectionNameKeyPath: String?, andPredicate predicate: NSPredicate?, contextType: ManageObjectContextType = .main) -> NSFetchedResultsController<NSManagedObject> {
        
        // Create and initialize the fetch results controller for parameters
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
		fetchRequest.sortDescriptors = sortDescriptors
		fetchRequest.predicate = predicate

		return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext(for: contextType), sectionNameKeyPath: sectionNameKeyPath, cacheName: nil) as! NSFetchedResultsController<NSManagedObject>
	}
    
    internal func rollBack(contextType: ManageObjectContextType = .main) {
        
        // Rollback context if has changes. All unsaved changes in the context will be reverted to the state of the parent context.
        let context = managedObjectContext(for: contextType)
        if !context.hasChanges {
            return
        }
        
        context.rollback()
    }

    internal func save(contextType: ManageObjectContextType = .main) {
        let context = managedObjectContext(for: contextType)
		if !context.hasChanges {
			return
		}
        
        let objectsToAdd = Array(context.insertedObjects.union(context.updatedObjects))
        
		context.performAndWait { () -> Void in
			do {
                
                // Obtain permanentIDs before saving
                try context.obtainPermanentIDs(for: objectsToAdd)
				try context.save()
                
                if context.parent != persistentStoreContext {
                    
                    // If parent is not the persistentStoreContext do nothing.
                    // You need to call save on the parent explicitly if you want to save changes in parent context.
                    return
                }
                
                // Save to persistent store
                context.parent?.performAndWait {
                    do {
                        try context.parent?.save()
                    } catch {
                        // Replace this implementation with code to handle the error appropriately.
                        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                        let nserror = error as NSError
                        NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                        abort()
                    }
                }
			} catch {
				// Replace this implementation with code to handle the error appropriately.
				// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
				let nserror = error as NSError
				NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
				abort()
			}
		}
	}

	internal func deleteObject(_ managedObject: NSManagedObject, contextType: ManageObjectContextType? = nil) {
        if contextType == nil {
            
            // If no context is stated use the context of the object
            managedObject.managedObjectContext?.performAndWait {
                managedObject.managedObjectContext?.delete(managedObject)
            }
            return
        }
        
        // Use context if stated explicitly
		managedObjectContext(for: contextType!).performAndWait { () -> Void in
			self.managedObjectContext(for: contextType!).delete(managedObject)
		}
	}

    @available(iOS 9.0, *)
    internal func deleteObjectsFromPersistentStore(for deleteRequest: NSBatchDeleteRequest, mergeContextType: ManageObjectContextType = .main) {
        do {
            deleteRequest.resultType = NSBatchDeleteRequestResultType.resultTypeObjectIDs
            let batchDeleteResult = try persistentStoreCoordinator.execute(deleteRequest, with: managedObjectContext(for: mergeContextType)) as! NSBatchDeleteResult
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey : batchDeleteResult.result!], into: [managedObjectContext(for: mergeContextType)])
        } catch _ {

        }
    }

    internal func deleteAllFromPersistentStoreObjectsBy(entityName: String, mergeContextType: ManageObjectContextType = .main) {
        if #available(iOS 9.0, *) {
            self.deleteObjectsFromPersistentStore(for: NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: entityName)), mergeContextType: mergeContextType)
        } else {
            // Fallback on earlier versions
        }
    }
    
    internal func deleteObjects(for entityName: String, withPredicate predicate: NSPredicate? = nil, fromContextType contextType: ManageObjectContextType = .main) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.predicate = predicate
        
        guard let results = objectsForFetchRequest(fetchRequest, contextType: contextType) else {
            
            // No results return
            return
        }
        
        for result in results {
            
            // Delete objects
            deleteObject(result)
        }
    }

	// MARK: -
	// MARK: Getters and setters

	public var persistentStoreCoordinator: NSPersistentStoreCoordinator {
		get {
			return coreDataStore.persistentStoreCoordinator
		}
	}
    
    // MARK: -
    // MARK: Private methods
    
    private func managedObjectContext(for type: ManageObjectContextType) -> NSManagedObjectContext {
        switch type {
        case .main:
            return mainQueueContext
        case .supplementary:
            if supplementaryContext == nil {
                NSLog("Supplementary context does not exist! Instatiate child context before invoking to it!")
                abort()
            }
            return supplementaryContext
        }
    }

}
