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
 *  <#Description#>
 */
@interface OSDCoreDataManager : NSObject

/*!
 *  Shared instance class method for accessing the shared instance of OSDCoreDataManager
 *
 *  \return Returns the shared instance of OSDCoreDataManager
 */
+ (instancetype)sharedManager;

+ (void)setManagedObjectModelName:(NSString *)modelName;


@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)save;

- (NSURL *)applicationDocumentsDirectory;

@end

@interface NSManagedObject (OSDCoreDataManagerAdditions)

+ (instancetype)insertIntoContext:(NSManagedObjectContext *)context;
+ (instancetype)insertIntoContext:(NSManagedObjectContext *)context name:(NSString *)name;

+ (NSFetchRequest *)fetchRequest;
+ (NSFetchRequest *)fetchRequestWithEntityName:(NSString *)entityName;

@end

#define OSDAssertMainThread() NSAssert([[NSThread currentThread] isMainThread], @"Must call %s on the main thread",__PRETTY_FUNCTION__)

#endif
