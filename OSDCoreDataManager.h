/*!
 *  OSDCoreDataManager.h
 *
 * Copyright (c) 2013 OpenSky, LLC
 *
 * Created by Skylar Schipper on 9/28/13
 */

#ifndef OSDCoreDataManager_h
#define OSDCoreDataManager_h

@import CoreData;

/*!
 *  A simple CoreData manager.  The `managedObjectContext` is a main thread context that talks to a private queue context that handles all database access.
 */
@interface OSDCoreDataManager : NSObject

/*!
 *  Shared instance class method for accessing the shared instance of OSDCoreDataManager
 *
 *  \return Returns the shared instance of OSDCoreDataManager
 */
+ (instancetype)sharedManager;

/*!
 *  Set the name of the data model.  This must be set before accessing the singleton.
 *
 *  If your app has a `TestDatabase.xcdatamodeld` then you would pass `@"TestDatabase"`
 *
 *  \param modelName The name of the model
 */
+ (void)setManagedObjectModelName:(NSString *)modelName;

/*!
 *  The main queue context.  All background contexts should be a child of this context.  Will be created lazily
 */
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

/*!
 *  The MOM for the data stack.  Will be created lazily
 */
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;

/*!
 *  The coordinator for the stack.  Will be created lazily
 */
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

/*!
 *  Saves the main thread context then saves the master context that pushes to the database.
 *
 *  This method is called automatically when the app enters background and again when it will terminate.
 */
- (void)save;

/*!
 *  Helper for getting at the documents directory.  This is where the database will be stored.
 *
 *  \return A NSURL pointing to the docs directory
 */
- (NSURL *)applicationDocumentsDirectory;

/*!
 *  A lot of dates get sent back from API as ISO 8601 this is a helper method for those
 *
 *  \param string The date string to parse
 *
 *  \return A date
 */
- (NSDate *)dateFromISO8601String:(NSString *)string;

@end

/*!
 *  NSManagedObject additions for making life easier.
 */
@interface NSManagedObject (OSDCoreDataManagerAdditions)

/*!
 *  Inserts a new object into the passed context.  The entity name will be the class name this is called on.
 *
 *  \param context The context to insert the object into
 *
 *  \return A new NSManagedObject subclass.
 */
+ (instancetype)insertIntoContext:(NSManagedObjectContext *)context;
/*!
 *  Inserts a new object into the passed context.
 *
 *  \param context The context to insert the object into.
 *  \param name    The name of the entity to create.
 *
 *  \return A new NSManagedObject subclass.
 */
+ (instancetype)insertIntoContext:(NSManagedObjectContext *)context name:(NSString *)name;

/*!
 *  Creates a new fetch request for the class.  The entity will be the name of the class this is called on.
 *
 *  \return A NSFetchRequest
 */
+ (NSFetchRequest *)fetchRequest;
/*!
 *  Creates a new fetch request for the class.
 *
 *  \param entityName The name of the entity to perform the fetch on
 *
 *  \return A NSFetchRequest
 */
+ (NSFetchRequest *)fetchRequestWithEntityName:(NSString *)entityName;

+ (NSArray *)getAll;
+ (NSArray *)getAllInContext:(NSManagedObjectContext *)context;
+ (NSArray *)getAllInContext:(NSManagedObjectContext *)context predicate:(NSPredicate *)predicate;
+ (NSArray *)getAllInContext:(NSManagedObjectContext *)context predicate:(NSPredicate *)predicate sortDescriptors:(NSArray *)sortDescriptors;

+ (NSUInteger)count;
+ (NSUInteger)countInContext:(NSManagedObjectContext *)context;

@end

//*** Macro for making sure methods aren't called off the main thread ***//
#define OSDAssertMainThread() NSAssert([[NSThread currentThread] isMainThread], @"Must call %s on the main thread",__PRETTY_FUNCTION__)

#endif
