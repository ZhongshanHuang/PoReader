//
//  SQLite_Bridging.h
//  
//
//  Created by HzS on 2022/9/26.
//

#ifndef SQLite_Bridging_h
#define SQLite_Bridging_h

#import <sqlite3.h>

int sqlite3_config_multithread(void);

int sqlite3_config_memstatus(int);

typedef void (*sqlite3_global_log)(void *, int, const char *);

int sqlite3_config_log(sqlite3_global_log, void *);

#endif /* SQLite_Bridging_h */
