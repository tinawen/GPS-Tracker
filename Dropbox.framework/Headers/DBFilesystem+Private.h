//
//  DBFilesystem+Private.h
//  DropboxSync
//
//  Created by Philip Rha on 5/13/13.
//  Copyright (c) 2012 Dropbox, Inc. All rights reserved.
//

#import "DBPath.h"


@interface DBFilesystem (Private)

/** Returns a list of files for a given query string, path.

 @return array of DBFileInfo objects, or `nil` if an error occurred.
 **/

- (NSArray *)searchPath:(DBPath *)path forKeyword:(NSString *)keyword error:(DBError **)error;

@end
