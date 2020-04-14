#!/bin/bash
export binlog_file=mysql-bin.000562
echo ${binlog_file}
mysqlbinlog --no-defaults --base64-output=decode-rows -v -v ${binlog_file} |awk '/###/{if($0~/UPDATE|INSERT|DELETE/)count[$2" "$NF]++}END{for(i in count)print i,"\t",count[i]}'|column -t|sort -k3nr > ${binlog_file}-`date +%Y%m%d-%H%M%S`
