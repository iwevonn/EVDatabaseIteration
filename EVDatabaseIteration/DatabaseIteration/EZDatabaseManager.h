//
//  EZDatabaseManager.h
//  EVDatabaseIteration
//
//  Created by iwevon on 2017/5/10.
//  Copyright © 2017年 iwevon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

//本地更新数据库sql的文件路径
#define DatabaseIterationDirectory  [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"EVDatabaseIteration.bundle/Iteration"]


@interface EZDatabaseManager : NSObject

+ (instancetype)sharedDBManager;

+ (FMDatabaseQueue *)dbQueue;

+ (NSString *)getDBPath;

+ (void)closeDB;

+ (NSString *)appVersion;

/**
 *  更新本地更新数据库版本纪录
 */
+ (BOOL)updateLocalDataVersion;

/**
 *  获取本地更新数据库版本纪录
 */
+ (NSString *)localDataVersion;

@end
