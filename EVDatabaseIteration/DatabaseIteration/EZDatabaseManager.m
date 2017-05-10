//
//  EZDatabaseManager.m
//  EVDatabaseIteration
//
//  Created by iwevon on 2017/5/10.
//  Copyright © 2017年 iwevon. All rights reserved.
//

#import "EZDatabaseManager.h"

static NSString * const DATABASE_NAME = @"EVDatabaseIteration.sqlite";
static NSString * const LOCALDATABASE_VERSION = @"EVLocalDataVersion";


@interface EZDatabaseManager ()

@property (nonatomic, strong) FMDatabaseQueue *dbQueue;

@end


@implementation EZDatabaseManager

#pragma mark - sharedDBManage

static EZDatabaseManager *_sharedDBManage = nil;
+ (instancetype)sharedDBManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedDBManage = [[self alloc] init];
    });
    return _sharedDBManage;
}

+ (FMDatabaseQueue *)dbQueue {
    return [[self sharedDBManager] dbQueue];
}

+ (NSString *)getDBPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDice = [paths objectAtIndex:0];
    return [documentsDice stringByAppendingPathComponent:DATABASE_NAME];
}

+ (void)closeDB {
    //1.关闭数据库
    [[[self sharedDBManager] dbQueue] close];
    //2.获取新的数据库
    [[self sharedDBManager] initDatabase];
}

+ (NSString *)appVersion {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *appVersion = nil;
    NSString *marketingVersionNumber = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *developmentVersionNumber = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (marketingVersionNumber && developmentVersionNumber) {
        if ([marketingVersionNumber isEqualToString:developmentVersionNumber]) {
            appVersion = marketingVersionNumber;
        } else {
            appVersion = [NSString stringWithFormat:@"%@.%@",marketingVersionNumber,developmentVersionNumber];
        }
    } else {
        appVersion = (marketingVersionNumber ? marketingVersionNumber : developmentVersionNumber);
    }
    return appVersion;
}

/**
 *  更新本地更新数据库版本纪录
 */
+ (BOOL)updateLocalDataVersion
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[self appVersion] forKey:LOCALDATABASE_VERSION];
    return [userDefaults synchronize];
}

/**
 *  获取本地更新数据库版本纪录
 */
+ (NSString *)localDataVersion {
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    return [userDefaults objectForKey:LOCALDATABASE_VERSION];
}


#pragma mark - alloc、init

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedDBManage = [super allocWithZone:zone];
    });
    return _sharedDBManage;
}

- (id)copyWithZone:(NSZone *)zone{
    return _sharedDBManage;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return _sharedDBManage;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self initDatabase];
    }
    return self;
}

#pragma mark - initDatabase

- (void)initDatabase {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dicectory = [paths objectAtIndex:0];
    NSString *writableDBPath = [dicectory stringByAppendingPathComponent:DATABASE_NAME];
    
    //将初始数据库拷贝过去
    if ([fm fileExistsAtPath:writableDBPath]) {
        self.dbQueue = [FMDatabaseQueue databaseQueueWithPath:writableDBPath];
    } else {
        NSString *dbPath= [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:DATABASE_NAME];
        NSError *error;
        [fm copyItemAtPath:dbPath toPath:writableDBPath error:&error];
        if (error) {
            NSLog(@"Failed to copy database...error handling here %@.", [error localizedDescription]);
        } else {
            //如果本地有数据库，本地的数据库需要保持最新版本的数据库
            [EZDatabaseManager updateLocalDataVersion];
        }
    }
}


@end
