#!/bin/bash
export LANG=C

#1分前時間をtimeへ保存
date=`date -d '1 minute ago' "+%Y-%m-%d %H:%M"`
Hostname_decied(){
        HOST=`hostname -s`
        if [[ "$HOST" = "dba02" ]]; then
                HOST="test-restsrh002"
        fi
        if [[ "$HOST" =~ ^"test" ]]; then
                ZABBIX_HOST="test-zabbix001"
        else
                ZABBIX_HOST="zabbix001"
        fi
}
mailProc() {
    MAIL_ADDRESS_NORMAL="develop-dba@gnavi.co.jp"
    MAIL_ADDRESS_NORMAL_CC=""
    #ホスト名を指定
    Hostname_decied
    ### Mail Send
    TITLE="[groonga] Query Check-ERROR_MAIL. ${HOST}"
    ADDRESS=${MAIL_ADDRESS_NORMAL}
    #for debug
    SendStat=1
    if [ ${SendStat} -gt 0 ];then
        if [ ! -z ${MAIL_ADDRESS_NORMAL_CC} ]; then
            CC=${MAIL_ADDRESS_NORMAL_CC}
            echo "${HOST} | ${DB_NAME} | ${ERROR_MESSAGE}" | mail -s "${TITLE}" -c "${CC}" ${ADDRESS}
        else
            echo "${HOST} | ${DB_NAME} | ${ERROR_MESSAGE}" | mail -s "${TITLE}" ${ADDRESS}
        fi
        echo "Send Mail:${SendStat}"
    else
        echo "No mail:${SendStat}"
    fi
}

File_name(){
        now_time=`date +%M`
        if [ "$now_time" = 00 ]; then
            FILE_TIME=`date -d '1 hour ago' +%Y%m%d%H`
            FILE_NAME="query-$FILE_TIME.log"
        else
            FILE_NAME="query.log"
        fi
}
Print_result(){
        echo $time
        datetime=`date +%H:%M:%S`
        echo  "実行前の時間=$datetime"
        sleep 40
        d_select_count=`$term ${FILE_PATH}/${FILE_NAME}| grep "${date}" |  grep -c '/d/select'`
        if [ "${d_select_count}" -eq 0 ]; then
            VAL=0
        else
            time VAL=`$term ${FILE_PATH}/${FILE_NAME}| grep "${date}" | grep '/d/select' | awk -F'|' '{print substr($1,1,16)}' | uniq -c | awk '{sum+=$1} END {print sum/60}' | awk '{printf("%d\n", $1 + 0.5)}'`
        fi
        datetime=`date +%H:%M:%S`
        echo "実行後の時間=$datetime"
}
Result_decide(){
        if [ -z ${VAL} ]; then
                echo "Incorrect value"
                return 1
        else
                echo "VAL=$VAL"
                return 0
        fi

}
#File Path,検索行数,スキーマ名を選択します。
Necessary_OPT=false
while getopts ":l:t:d:" OPT; do
                case ${OPT} in
                "l")
                   Necessary_OPT=true
                   FILE_PATH=${OPTARG}
                ;;
                "t")
                   Necessary_OPT=true
                   count=${OPTARG}
                   term="tail -$count"
                ;;
                "d")
                   Necessary_OPT=true
                   DB_NAME=${OPTARG}
                ;;
                *)
                  Necessary_OPT=false
                ;;
                esac
    done
LOG="/home/groonga/groonga-mnt/groonga_qps_sender/logs"
LOGFILE="${LOG}/`basename $0`_`date "+%Y%m%d%H%M"_${DB_NAME}_qps`.log"
{
#Host名を取得します。
Hostname_decied

#結果を出力します。
if [ "${Necessary_OPT}" != true ]; then
            echo "オプション設定方法
-l) ログファイルのパス
-t) tailの行数
-d) DB名"
       exit 1
else
    #ファイル名を指定
    File_name
    #結果を出力
    Print_result
fi
#結果を判断します。
Result_decide

if [ $? = 0 ]; then
    /usr/local/zabbix/bin/zabbix_sender -z $ZABBIX_HOST -p 10051 -s ${HOST} -k groonga.qps.${DB_NAME} -o ${VAL} -vv
else
    exit 1
fi

} 2>&1 |
while read line;
do
    echo "${line}" | tee -a ${LOGFILE}
done
    grep -q -e denied -e cannot -e "failed: 1" -e invalid -e "Incorrect value" -e error -e NO ${LOGFILE}
    if [ $? = 0 ]; then
        ERROR_MESSAGE=`grep -e "failed: 1" -e denied -e invalid -e cannot -e No -e "Incorrect value" -e error ${LOGFILE}`
        #エラーメッセージを送信
        mailProc
    fi
        find $LOG -name "*.log" -mtime +10 -exec rm {} \;

                                                                                                                               135,0-1      末尾

