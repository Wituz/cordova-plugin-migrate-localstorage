/** Code Adapted from https://github.com/MaKleSoft/jairemix/cordova-plugin-migrate-localstorage */

#import "MigrateLocalStorage.h"

#define TAG @"\nMigrateLS"

#define ORIG_FOLDER @"WebKit/WebsiteData/LocalStorage"
#define ORIG_LS_FILEPATH @"WebKit/WebsiteData/LocalStorage/http_localhost_8080.localstorage"
#define ORIG_LS_CACHE @"Caches/file__0.localstorage"
#define ORIG_IDB_FILEPATH @"WebKit/LocalStorage/___IndexedDB"

#define TARGET_LS_FILEPATH @"WebKit/WebsiteData/LocalStorage/app_localhost_0.localstorage"
#define TARGET_IDB_FILEPATH @"WebKit/WebsiteData/IndexedDB"

@implementation MigrateLocalStorage

NSString* extendString(NSString* root, NSString* path)
{
    return [root stringByAppendingString:path];
}

NSString* extendPath(NSString* root, NSString* path)
{
    return [root stringByAppendingPathComponent:path];
}

void deletePath(NSFileManager* fileManager, NSString* path)
{
    NSLog(@"%@ deleting path: %@ ", TAG, path);

    NSError* err;
    BOOL success = [fileManager removeItemAtPath:path error:&err];
    if (!success) {
        NSLog(@"%@ error deleting path: %@ ", TAG, err.localizedDescription);
    }
}

void move(NSFileManager* fileManager, NSString* src, NSString* dest)
{
    if (![fileManager fileExistsAtPath:src]) {
        NSLog(@"%@ source file does not exist", TAG);
        return;
    }

    if ([fileManager fileExistsAtPath:dest]) {
        NSLog(@"%@ target file exists", TAG);
        return;
    }

    if (![fileManager createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) {
        NSLog(@"%@ error creating target file", TAG);
        return;
    }

    NSError* err;
    BOOL success = [fileManager moveItemAtPath:src toPath:dest error:&err];
    if (!success) {
        NSLog(@"%@ error moving path: %@ ", TAG, err.localizedDescription);
    }
}

void printChildren(NSFileManager* fileManager, NSString* path)
{
    NSLog(@"\n%@ listing found files for path: %@", TAG, path);

    NSDirectoryEnumerator* dirEnum = [fileManager enumeratorAtPath:path];
    NSString* file;

    while ((file = [dirEnum nextObject])) {
        NSString* childPath = extendPath(path, file);
        NSString* readble = [fileManager isReadableFileAtPath: childPath] ? @"r" : @"";
        NSString* writable = [fileManager isWritableFileAtPath: childPath] ? @"w" : @"";
        NSString* executable = [fileManager isExecutableFileAtPath: childPath] ? @"e" : @"";
        NSString* deletable = [fileManager isDeletableFileAtPath: childPath] ? @"d" : @"";
        NSLog(@"%@ file found: %@ %@ %@ %@ %@", TAG, file, readble, writable, executable, deletable);
    }
}

NSString* addBundleIDForSimulator(NSString* path)
{
    #if TARGET_IPHONE_SIMULATOR
        NSString* bundleIdentifier = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        bundleIdentifier = extendString(@"/", bundleIdentifier);

        NSMutableString* pathMutable = [NSMutableString stringWithString:path];
        NSRange range = [pathMutable rangeOfString:@"WebKit"];
        long idx = range.location + range.length;
        [pathMutable insertString:bundleIdentifier atIndex:idx];

        return pathMutable;
    #endif

    return path;
}

NSString* fallbackIfMissing(NSFileManager* fileManager, NSString* path, NSString* fallback)
{
    return [fileManager fileExistsAtPath:path] ? path : fallback;
}

void migrateLocalStorage(NSFileManager* fileManager, NSString* appLibraryFolder)
{
    NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:extendPath(appLibraryFolder, @"WebKit/WebsiteData/LocalStorage") error:Nil];
    
    NSLog(@"%@", dirs);
    NSString* original = fallbackIfMissing(fileManager,
        extendPath(appLibraryFolder, ORIG_LS_FILEPATH),
        extendPath(appLibraryFolder, ORIG_LS_CACHE)
    );
    NSString* target = addBundleIDForSimulator(extendPath(appLibraryFolder, TARGET_LS_FILEPATH));
    NSLog(@"%@ migrating localStorage", TAG);
    NSLog(@"%@ original %@", TAG, original);
    NSLog(@"%@ target %@", TAG, target);
    move(fileManager, original, target);
    move(fileManager, extendString(original, @"-shm"), extendString(target, @"-shm"));
    move(fileManager, extendString(original, @"-wal"), extendString(target, @"-wal"));
}

void migrateIndexedDB(NSFileManager* fileManager, NSString* appLibraryFolder)
{
    NSString* original = extendPath(appLibraryFolder, ORIG_IDB_FILEPATH);
    NSString* target = addBundleIDForSimulator(extendPath(appLibraryFolder, TARGET_IDB_FILEPATH));
    NSLog(@"%@ migrating indexedDB", TAG);
    NSLog(@"%@ original %@", TAG, original);
    NSLog(@"%@ target %@", TAG, target);
    move(fileManager, original, target);
}

- (void)pluginInitialize
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    // Check if already migrated
    NSString* targetLS = extendPath(appLibraryFolder, TARGET_LS_FILEPATH);
    if ([fileManager fileExistsAtPath:targetLS]) {
        NSLog(@"%@ already migrated", TAG);
        return;
    }

    deletePath(fileManager, extendPath(appLibraryFolder, TARGET_IDB_FILEPATH));

    migrateIndexedDB(fileManager, appLibraryFolder);
    migrateLocalStorage(fileManager, appLibraryFolder);
}

@end
