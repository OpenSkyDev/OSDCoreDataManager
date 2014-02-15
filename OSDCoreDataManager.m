/*!
 *  OSDCoreDataManager.m
 *
 * Copyright (c) 2013 OpenSky, LLC
 *
 * Created by Skylar Schipper on 9/28/13
 */


#import "OSDCoreDataManager.h"
#import <objc/runtime.h>

id static _sharedOSDCoreDataManager = nil;
NSString static *_osdCoreDataManagerModelName = nil;

void osd_CoreData_MethodSwizzle(Class c, SEL origSEL, SEL overrideSEL) {
    Method origMethod = class_getInstanceMethod(c, origSEL);
    Method overrideMethod = class_getInstanceMethod(c, overrideSEL);
    if(class_addMethod(c, origSEL, method_getImplementation(overrideMethod), method_getTypeEncoding(overrideMethod))) {
        class_replaceMethod(c, overrideSEL, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, overrideMethod);
    }
}

@interface OSDCoreDataManager ()

@property (nonatomic, strong) NSManagedObjectContext *masterObjectContext;
@property (nonatomic, strong) NSDateFormatter *ISO8601Formatter;

@end

@implementation OSDCoreDataManager
@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;


#pragma mark -
#pragma mark - Initialization
- (id)init {
	self = [super init];
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidRestoreFromBackground:) name:UIApplicationDidBecomeActiveNotification object:nil];
	}
	return self;
}

#pragma mark -
#pragma mark - Singleton
+ (instancetype)sharedManager {
	@synchronized (self) {
        if (!_sharedOSDCoreDataManager) {
            _sharedOSDCoreDataManager = [[[self class] alloc] init];
        }
        return _sharedOSDCoreDataManager;
    }
}

#pragma mark -
#pragma mark - Setup
+ (void)setManagedObjectModelName:(NSString *)modelName {
    _osdCoreDataManagerModelName = modelName;
}

#pragma mark -
#pragma mark - Core Data Helpers
- (void)save {
    if (![self.managedObjectContext hasChanges] && ![self.masterObjectContext hasChanges]) return;
    
    [self.managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        [self.managedObjectContext save:&error];
        if (error) {
            NSLog(@"%@",error);
        }
        [self.masterObjectContext performBlock:^{
            NSError *bgError = nil;
            [self.masterObjectContext save:&bgError];
            if (bgError) {
                NSLog(@"%@",error);
            }
        }];
    }];
}

#pragma mark -
#pragma mark - Getters

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _managedObjectContext.parentContext = self.masterObjectContext;
    }
    return _managedObjectContext;
}
- (NSManagedObjectContext *)masterObjectContext {
    if (_masterObjectContext) {
        return _masterObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _masterObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_masterObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _masterObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    if (!_osdCoreDataManagerModelName) {
        [NSException raise:@"No managed object name found" format:@"Please set a manage object model name by calling +[SSCoreDataManager setManagedObjectModelName:]"];
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:_osdCoreDataManagerModelName withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSDictionary *options = @{NSInferMappingModelAutomaticallyOption: @YES, NSMigratePersistentStoresAutomaticallyOption: @YES};
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[self storeURL] options:options error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        [NSException raise:error.domain format:@"%@",[error localizedDescription]];
    }
    
    return _persistentStoreCoordinator;
}


#pragma mark -
#pragma mark - Store Info
- (NSURL *)storeURL {
    return [[self applicationDocumentsDirectory] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",_osdCoreDataManagerModelName]];
}

#pragma mark -
#pragma mark - Application's Documents directory

- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark -
#pragma mark - Application Live Cycle

- (void)_applicationDidRestoreFromBackground:(NSNotification *)notification {
    
}
- (void)_applicationDidEnterBackground:(NSNotification *)notification {
    [self save];
}
- (void)_applicationWillTerminate:(NSNotification *)notification {
    [self save];
}

#pragma mark -
#pragma mark - Date Helpers
- (NSDateFormatter *)ISO8601Formatter {
    if (!_ISO8601Formatter) {
        _ISO8601Formatter = [[NSDateFormatter alloc] init];
        _ISO8601Formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    }
    return _ISO8601Formatter;
}
- (NSDate *)dateFromISO8601String:(NSString *)string {
    return [self.ISO8601Formatter dateFromString:string];
}

@end

@implementation NSManagedObject (OSDCoreDataManagerAdditions)

+ (void)load {
    osd_CoreData_MethodSwizzle(self, @selector(willSave), @selector(osd_willSave));
}

+ (instancetype)insertIntoContext:(NSManagedObjectContext *)context {
    return [self insertIntoContext:context name:NSStringFromClass([self class])];
}
+ (instancetype)insertIntoContext:(NSManagedObjectContext *)context name:(NSString *)name {
    return [NSEntityDescription insertNewObjectForEntityForName:name inManagedObjectContext:context];
}

+ (NSFetchRequest *)fetchRequest {
    return [self fetchRequestWithEntityName:NSStringFromClass([self class])];
}
+ (NSFetchRequest *)fetchRequestWithEntityName:(NSString *)entityName {
    return [NSFetchRequest fetchRequestWithEntityName:entityName];
}

+ (NSArray *)getAll {
    OSDAssertMainThread();
    return [self getAllInContext:[[OSDCoreDataManager sharedManager] managedObjectContext]];
}
+ (NSArray *)getAllInContext:(NSManagedObjectContext *)context {
    return [self getAllInContext:context predicate:nil];
}
+ (NSArray *)getAllInContext:(NSManagedObjectContext *)context predicate:(NSPredicate *)predicate {
    return [self getAllInContext:context predicate:predicate sortDescriptors:nil];
}
+ (NSArray *)getAllInContext:(NSManagedObjectContext *)context predicate:(NSPredicate *)predicate sortDescriptors:(NSArray *)sortDescriptors {
    NSFetchRequest *fetchRequest = [self fetchRequest];
    fetchRequest.predicate = predicate;
    fetchRequest.sortDescriptors = sortDescriptors;
    return [context executeFetchRequest:fetchRequest error:nil];
}

+ (NSUInteger)count {
    OSDAssertMainThread();
    return [self countInContext:[[OSDCoreDataManager sharedManager] managedObjectContext]];
}
+ (NSUInteger)countInContext:(NSManagedObjectContext *)context {
    return [context countForFetchRequest:[self fetchRequest] error:nil];
}

- (void)osd_willSave {
    [self osd_willSave];
    SEL createdSelector = NSSelectorFromString(@"setCreatedAt:");
    if ([self respondsToSelector:createdSelector] && ![self primitiveValueForKey:@"createdAt"]) {
        [self setPrimitiveValue:[NSDate date] forKey:@"createdAt"];
    }
    SEL updatedSelector = NSSelectorFromString(@"setUpdatedAt:");
    if ([self respondsToSelector:updatedSelector]) {
        [self setPrimitiveValue:[NSDate date] forKey:@"updatedAt"];
    }
}

@end
