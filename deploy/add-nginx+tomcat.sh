#!/bin/bash
##########获取可用的DOWNPORT，HTTPPORT，ADDRESS
get_port()
{
    if [[ ! -d ${INSTANCE} || `ls -l ${INSTANCE}/|wc -l` == 0 ]];then
        DOWNPORT="9001"
        HTTPPORT="8001"
        ADDRESS="10001"
    else
        DOWNPORT=$[`cat ${INSTANCE}/*/*/conf/server.xml |grep "Server port" |awk -F = '{print $2}'|awk '{print $1}' |sed 's/\"//g'|awk 'BEGIN{x=$1;} {for(i=1;i<=NF;i++)if($i>x)x=$i;} END{print x}'`+1]
        HTTPPORT=$[`cat ${INSTANCE}/*/*/conf/server.xml |grep "HTTP" |awk '{print $2}'|grep "port"|awk -F "=" '{print $2}' |sed 's/\"//g'|awk 'BEGIN{x=$1;} {for(i=1;i<=NF;i++)if($i>x)x=$i;} END{print x}'`+1]
        ADDRESS=$[`cat ${INSTANCE}/*/*/bin/start.sh |grep "address="|awk -F address= '{print $2}'|sed 's/\"//g'|awk 'BEGIN{x=$1;if(x<1)x=10000;} {for(i=1;i<=NF;i++)if($i>x)x=$i;} END{print x}'`+1]
    fi
}

############### SET TOMCAT SERVER ##################################
tomcat_add()
{
    NEW_SERVER=server$[`ls -l ${INSTANCE}/${DOMAIN}|grep server|wc -l`+1]
    mkdir -p ${NEW_SERVER}/{logs,temp,webapps,work}
    cp -r catalina_base/conf  ${NEW_SERVER}/
    if [[ `${CATALINA_HOME}/bin/version.sh|grep "Server number"|awk '{print $3}'|grep "^6"|wc -w` == 0 ]];then
        mv ${NEW_SERVER}/conf/server.xml.7 ${NEW_SERVER}/conf/server.xml
    fi

    sed -i "s#9001#${DOWNPORT}#g"	${NEW_SERVER}/conf/server.xml
    sed -i "s#8001#${HTTPPORT}#g"	${NEW_SERVER}/conf/server.xml
    sed -i "s#/workspace/work#${WORK}/${DOMAIN}#g"	${NEW_SERVER}/conf/Catalina/localhost/ROOT.xml
    mv ${NEW_SERVER} ${INSTANCE}/${DOMAIN}/
}

################### SET NGINX SERVER ################################ 
nginx_new() #在domains里新增一个新的nginx配置文件
{
    NEW_NGINX_FILE="${NGINX}/conf/domains/${DOMAIN}"
    cp xxx.com  ${NEW_NGINX_FILE}
    PRE_DOMAIN=${DOMAIN%.*}
    sed -i "s#xxx.com#${DOMAIN}#g" ${NEW_NGINX_FILE}
    sed -i "s#tomcat_xxx#tomcat_${DOMAIN}#g" ${NEW_NGINX_FILE}
    sed -i "s#8001#${HTTPPORT}#g" ${NEW_NGINX_FILE}
    sed -i "s#nginx_home#${NGINX}#g" ${NEW_NGINX_FILE}
    sed -i "s#work#${WORK}#g" ${NEW_NGINX_FILE}
    sed -i "/server_name/s#;# ${PRE_DOMAIN}\.local;#g" ${NEW_NGINX_FILE}
}

nginx_add() #配置文件中添加一行：server 127.0.0.1:{httpport}  weight=10 max_fails=2 fail_timeout=30s;
{
    NGINX_FILE="${NGINX}/conf/domains/${DOMAIN}"
    LINE_NUM=`cat -n ${NGINX_FILE} |grep "server 127"|tail -n 1|awk '{print $1}'`
    sed -i "${LINE_NUM}a\ \ \ \ server\ 127.0.0.1\:${HTTPPORT}\ \ weight\=10\ max_fails\=2\ fail_timeout\=30s\;" ${NGINX_FILE}
}
################## FOR REAL ###############################
if [[ $1 == "" ]];then
        echo "Usage: $0 ***.com"
        exit 0
fi
DOMAIN=$1
get_port
source ../env.sh #仅用到catalina_home


cd `dirname $0`
if [ -d ${INSTANCE}/${DOMAIN} ];then
	read -p "已有同域名应用,是否再新建一个?(yes/no)" YES
	case $YES in
		y|yes|Y|YES)
			tomcat_add
			nginx_add
	esac
else
	mkdir -p ${WORK}/${DOMAIN}
    mkdir -p ${SHELL}/${DOMAIN}
    mkdir -p ${INSTANCE}/${DOMAIN}
    mkdir -p ${NGINX}/logs/${DOMAIN}
    mkdir -p ${NGINX}/conf/domains
	tomcat_add
	nginx_new
fi