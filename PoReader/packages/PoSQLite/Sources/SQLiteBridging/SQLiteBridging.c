//
//  SQLite_Bridging.c
//  
//
//  Created by HzS on 2022/9/26.
//

#include "SQLiteBridging.h"

int sqlite3_config_multithread(void)
{
    return sqlite3_config(SQLITE_CONFIG_MULTITHREAD);
}

int sqlite3_config_memstatus(int a)
{
    return sqlite3_config(SQLITE_CONFIG_MEMSTATUS, a);
}

int sqlite3_config_log(sqlite3_global_log a, void *b)
{
    return sqlite3_config(SQLITE_CONFIG_LOG, a, b);
}
