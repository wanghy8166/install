#!/bin/bash    
# 环境变量    
export LANG=en_US.utf8    
export PGHOME=/usr/pgsql-10
export LD_LIBRARY_PATH=$PGHOME/lib:/lib64:/usr/lib64:/usr/local/lib64:/lib:/usr/lib:/usr/local/lib    
#export DATE=`date +"%Y%m%d%H%M"`    
export PATH=$PGHOME/bin:$PATH:.    
  
# 程序变量    
TODAY=`date +%Y%m%d`    
EMAIL="12345678@qq.com"    
BAKBASEDIR="/pg/pg_dump"    
mkdir -p $BAKBASEDIR/${TODAY}
chown postgres:postgres -R $BAKBASEDIR
RESERVE_DAY=3

HOST="127.0.0.1"    
PORT="5432"    
ROLE="postgres"    
  
# 不一致备份, 按单表进行.    
for DB in `psql -A -q -t -h $HOST -p $PORT -U $ROLE postgres -c "select datname from pg_database where datname not in ('postgres','template0','template1')"`    
do    
echo
echo -e "------`date +%F\ %T`----Start Backup----IP:$HOST PORT:$PORT DBNAME:$DB TYPE:$BAKTYPE TO:$BAKBASEDIR------"    
  
for TABLE in `psql -A -q -t -h $HOST -p $PORT -U $ROLE $DB -c "select schemaname||'.'||tablename from pg_tables where schemaname !~ '^pg_' and schemaname <>'information_schema'"`    
do    
pg_dump -f ${BAKBASEDIR}/${TODAY}/${DB}-${TABLE}-${TODAY}.dmp.ing -F c -t $TABLE --lock-wait-timeout=6000 -E UTF8 -h ${HOST} -p ${PORT} -U ${ROLE} -w ${DB}    
if [ $? -ne 0 ]; then    
echo -e "backup $HOST $PORT $DB $BAKBASEDIR error \n `date +%F%T` \n"|mutt -s "ERROR : PostgreSQL_backup " ${EMAIL}    
echo -e "------`date +%F\ %T`----Error Backup----IP:$HOST PORT:$PORT DBNAME:$DB TABLE:$TABLE TO:$BAKBASEDIR------"    
rm -f ${BAKBASEDIR}/${DB}-${TABLE}-${TODAY}.dmp.ing    
break    
fi    
mv ${BAKBASEDIR}/${TODAY}/${DB}-${TABLE}-${TODAY}.dmp.ing ${BAKBASEDIR}/${TODAY}/${DB}-${TABLE}-${TODAY}.dmp    
echo -e "------`date +%F\ %T`----Success Backup----IP:$HOST PORT:$PORT DBNAME:$DB TABLE:$TABLE TO:$BAKBASEDIR------"    
done    
  
done    
  
echo
echo -e "find ${BAKBASEDIR} -daystart -mtime +${RESERVE_DAY} -name "*.dmp" -delete"   
find ${BAKBASEDIR} -daystart -mtime +${RESERVE_DAY} -name "*.dmp" -delete
find ${BAKBASEDIR} -daystart -mtime +${RESERVE_DAY} -name "*.log" -delete
echo

# 用dmp恢复db示例
# for dmp in `ls /pg/pg_dump/20190310/*20190310*`    
# do    
#   pg_restore -h 127.0.0.1 -p 5432 -U 用户名 -d 数据库名 $dmp
# done
