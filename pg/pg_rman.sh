#!/bin/bash    
# 环境变量    
export LANG=en_US.utf8
export PATH=$PATH:/usr/pgsql-10/bin
export PGDATA=/pg/data
export BACKUP_PATH=/pg/pg_rman
mkdir -p $BACKUP_PATH
chown postgres:postgres -R $BACKUP_PATH

# 程序变量    
TODAY=`date +%Y%m%d-%H%M%S`
BACK_LOG=${BACKUP_PATH}/pg_rman-${TODAY}.log
find ${BACKUP_PATH} -mtime +15 -name "pg_rman-*.log" -exec rm -rf {} \;

week=$(date +%w)
echo "星期:"$week 1>> $BACK_LOG 2>&1
if [ $week = 0 ];then level=full 
fi
if [ $week = 1 ];then level=incremental 
fi
if [ $week = 2 ];then level=incremental 
fi
if [ $week = 3 ];then level=incremental 
fi
if [ $week = 4 ];then level=incremental 
fi
if [ $week = 5 ];then level=incremental 
fi
if [ $week = 6 ];then level=incremental 
fi
echo "备份级别:"$level 1>> $BACK_LOG 2>&1
echo 1>> $BACK_LOG 2>&1

#START BACKUP
echo "START BACKUP............................................" 1>> $BACK_LOG 2>&1
echo 1>> $BACK_LOG 2>&1
#查看备份
pg_rman show detail 1>> $BACK_LOG 2>&1
echo 1>> $BACK_LOG 2>&1
#执行备份命令
pg_rman backup --backup-mode=$level --progress 1>> $BACK_LOG 2>&1
echo 1>> $BACK_LOG 2>&1
#备份集校验
pg_rman validate 1>> $BACK_LOG 2>&1
echo 1>> $BACK_LOG 2>&1
#执行备份(归档)命令
pg_rman backup --backup-mode=arch --progress 1>> $BACK_LOG 2>&1
echo 1>> $BACK_LOG 2>&1
#备份集校验
pg_rman validate 1>> $BACK_LOG 2>&1
echo 1>> $BACK_LOG 2>&1
#检查备份是否成功
error_num=`pg_rman show | awk 'BEGIN{n=0}{if(NR > 3 && $8 != "OK")n++}END{print n}'`
if [ $error_num -gt 0 ];then
    echo ${TODAY}-`hostname`-"PostgreSQL备份失败:"$error_num 1>> $BACK_LOG 2>&1
    echo 1>> $BACK_LOG 2>&1
fi
#清理无效备份集
pg_rman purge 1>> $BACK_LOG 2>&1
echo 1>> $BACK_LOG 2>&1
#查看备份
pg_rman show detail 1>> $BACK_LOG 2>&1
echo 1>> $BACK_LOG 2>&1

echo "BACKUP  END............................................" 1>> $BACK_LOG 2>&1
