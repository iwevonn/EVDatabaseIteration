//
//  EVDatabaseIteration.m
//  EVDatabaseIteration
//
//  Created by iwevon on 2017/5/10.
//  Copyright © 2017年 iwevon. All rights reserved.
//

#import "EVDatabaseIteration.h"
#import "EZDatabaseManager.h"

static NSString * const ITERATION_NAME = @"EZIteration";

@implementation EVDatabaseIteration

#pragma mark - 本地存在数据库

//本地bundle中数据一定要是最新的
+ (BOOL)updateJSONDataVersion {
    
    //初始化数据库
    [EZDatabaseManager sharedDBManager];
    
    /* 1.防止App包回溯
     tip: 一般App上架到市场是不存在这样情况的，企业版本比较特殊，可以安装旧版本
     解决方法:升级数据库成功后会在本地存App的版本号， 现在根据这个数据判断，如果高于现在安装的版本号，则删除App中的数据库，创建一个新的无任何记录的数据库
     */
    [self appRecall];
    
    /* 2.遍历需要更新的sql文件
     本地数据版本 > 需要更新的sql文件 <= App当前版本
     更新sql使用的事物的方式操作，按sql文件为单位去更新数据库
     */
    NSString *localDataVersion = [EZDatabaseManager localDataVersion];
    NSString *appVersion = [EZDatabaseManager appVersion];
    BOOL success = [self updateDataBaseVersion:localDataVersion appVersion:appVersion];
    
    /* 3.更新本地数据库版本号
     更新成功后：本地的数据 == App当前版本
     */
    success = success ? [EZDatabaseManager updateLocalDataVersion] : NO;
    
    return success;
}

+ (BOOL)updateDataBaseVersion:(NSString *)localDataVersion appVersion:(NSString *)appVersion {
    //判断是否有更新的sql文件
    if ([localDataVersion isEqualToString:appVersion]) { return NO; }
    
    //需要将原始版本号"2.2.3"转换为sql文件版本格式"2_2_3"
    NSString *startVersion = [localDataVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    startVersion = [NSString stringWithFormat:@"%@_%@.sql", ITERATION_NAME, startVersion];
    
    NSString *endVersion = [appVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    endVersion = [NSString stringWithFormat:@"%@_%@.sql", ITERATION_NAME, endVersion];
    
    
    BOOL isResult = YES; //更新sql结果
    
    NSString *direPath = DatabaseIterationDirectory;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //遍历文件中数据可升级的sql文件
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:direPath error:NULL];
    
    /* 约定版本号时，如某一段中有多位数，需要用"0"补齐
     如：2.3.05，最后一段"5"前需要补"0"（出现：2.2.3，2.3.10，需改成：2.2.03，2.3.10）
     */
    //不区分大小写比较|compare:排序规则|忽略字符串的长度|不区分大小写并返回升序或降序
    NSStringCompareOptions comparisonOptions = NSCaseInsensitiveSearch|
    NSNumericSearch|
    NSWidthInsensitiveSearch|
    NSForcedOrderingSearch;
    NSComparator sort = ^(NSString *obj1, NSString *obj2){
        NSRange range = NSMakeRange(0, obj1.length);
        return [obj1 compare:obj2 options:comparisonOptions range:range];
    };
    NSArray *resultArray = [contents sortedArrayUsingComparator:sort];
    
    //从下个版本开始升级
    for (NSString *fileName in resultArray) {
        
        if ([fileName caseInsensitiveCompare:startVersion] ==  NSOrderedDescending && //降序->"文件路径>当前的版本号"
            [fileName caseInsensitiveCompare:endVersion] <= NSOrderedSame    //升序或相等->"文件路径<=当前的版本号"
            ) {
            
            NSString *filePath = [direPath stringByAppendingPathComponent:fileName];
            //更新sql文件中sql语句
            isResult = isResult ? [self updateDBWithSqlPath:filePath] : NO;
        }
    }
    return isResult;
}

#pragma mark 更新SQL语句

+ (BOOL)updateDBWithSqlPath:(NSString *)sqlPath {
    
    BOOL success = NO;
    NSString *sqlContent = [NSString stringWithContentsOfFile:sqlPath encoding:NSUTF8StringEncoding error:nil];
    NSArray *sqlArray = [sqlContent componentsSeparatedByString:@";"];
    if (sqlArray.count) {
        success = [self updateDBWithSqlArray:sqlArray];
    }
    return success;
}

+ (BOOL)updateDBWithSqlArray:(NSArray *)sqlArray {
    
    __block BOOL success = YES;
    //用事务会有大幅效率提升
    [[EZDatabaseManager dbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        for (NSString *detailStr in sqlArray) {
            NSString *updateSql = [detailStr stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]; //去空格
            if (updateSql.length == 0) continue; //过滤掉空的sql
            BOOL result = [db executeUpdate:updateSql];
            if (!result && [db hadError]) {
                NSString *sqlErrTitle = [NSString stringWithFormat:@"SQL Err - %d\n %@", [db lastErrorCode], [db lastErrorMessage]];
                NSLog(@"sqlErrTitle:%@, updateSql:%@", sqlErrTitle, updateSql);
                success = NO;
                *rollback = YES;
                break;
            }
        }
    }];
    return success;
}

#pragma mark - private
/*
 tip: 一般App上架到市场是不存在这样情况的，企业版本比较特殊，可以安装旧版本
 解决方法:升级数据库成功后会在本地存App的版本号， 现在根据这个数据判断，如果高于现在安装的版本号，则删除App中的数据库，创建一个新的无任何记录的数据库
 */
+ (void)appRecall {
    NSString *appVersion = [EZDatabaseManager appVersion];
    NSString *dbVersion = [EZDatabaseManager localDataVersion];
    
    if ([appVersion caseInsensitiveCompare:dbVersion] ==  NSOrderedDescending) { //降序
        //删除缓存文件
        NSString *dbPath = [EZDatabaseManager getDBPath];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        //1.删除数据库文件
        BOOL success = [fileManager removeItemAtPath:dbPath error:NULL];
        //2.重新连接数据库，去本地的数据库
        if (success) {
            [EZDatabaseManager closeDB];
        }
        
        NSLog(@"%@", @"tip: 一般App上架到市场是不存在这样情况的，企业版本比较特殊，可以安装旧版本\n解决方法:二期升级数据库成功后会在本地存App的版本号， 现在根据这个数据判断，如果高于现在安装的版本号，则删除App中的数据库，创建一个新的无任何记录的数据库");
    }
}


@end
