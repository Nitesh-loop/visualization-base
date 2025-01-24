#!/bin/bash

tempPath='/home/oracle/alertScript'
. /u01/oracle/19c/dbhome/CDBVIS_test.env




# HTML output file for the health check
HTMLFILE="/home/oracle/alertScript/log/HEALTH_CHECK_REPORT_FOR_$(hostname)_$(date +%Y%m%d_%H%M%S).html"

# Threshold for tablespace usage
THRESHOLD=90

# EBS Login URL
url="http://test.jupiter.com:8050/OA_HTML/AppsLocalLogin.jsp"



# Fuction for styling Add HTML headers with CSS styling

genrateStyle() {
echo "<html><head><title>Oracle Database Health Check</title>" >> $HTMLFILE
echo "<style>
    body {
        font-family: Arial, sans-serif;
        margin: 20px;
        background-color: #f4f4f9;
        color: #333;
    }
    h1 {
        color: #0056b3;
    }
    h2 {
        color: #333;
        border-bottom: 2px solid #0056b3;
        padding-bottom: 5px;
    }
    pre {
        background-color: #e9ecef;
        padding: 10px;
        border-radius: 5px;
        overflow-x: auto;
    }
	code {
        font-family: Consolas, 'Courier New', Courier, monospace;
    }
    hr {
        border: 1px solid #0056b3;
        margin: 20px 0;
    }
    .alert {
        background-color: #ffdddd;
        color: #d8000c;
        padding: 10px;
        border-left: 6px solid #d8000c;
        margin-bottom: 20px;
        border-radius: 5px;
    }
    .warning {
        color: #d8000c;
		padding: 15px;
        border-radius: 5px;
        overflow-x: auto;
    }
    p {
        font-size: 14px;
    }
</style>" >> $HTMLFILE

echo "</head><body>" >> $HTMLFILE
echo "<h1>Oracle Database Health Check - $(date)</h1>" >> $HTMLFILE
echo "<hr>" >> $HTMLFILE

}


# Function to run SQL script and append results to the HTML file
run_sql_1() {
    # Defining Parameters
    local sql_query="$1"
    local section_title="$2"
    local check_threshold="$3"

    echo "<h2>$section_title</h2>" >> $HTMLFILE
    echo "<pre><code>" >> $HTMLFILE

    sqlplus -s / as sysdba <<EOF >> $HTMLFILE
    SET LINES 200
		SET PAGES 100
		COL con_name FORM A15 HEAD "Container|Name"
		COL tablespace_name FORM A25
		COL free_space_gb FORM 999,999,999.99 HEAD "Free|Space GB"
		COL allocated_space_gb FORM 999,999,999.99 HEAD "Allocated|Space GB"
		COL max_allocated_gb FORM 999,999,999.99 HEAD "Max|Allocated GB"
		COL used_percentage FORM 999.99 HEAD "Used|Percentage"
    $sql_query
    EXIT;
EOF

    if [ "$check_threshold" == "true" ]; then
        # Check for tablespaces exceeding the threshold
        sqlplus -s / as sysdba <<EOF > $tempPath/tablespace_check.txt
        SET LINES 200
		SET PAGES 100
		COL con_name FORM A15 HEAD "Container|Name"
		COL tablespace_name FORM A25
		COL free_space_gb FORM 999,999,999.99 HEAD "Free|Space GB"
		COL allocated_space_gb FORM 999,999,999.99 HEAD "Allocated|Space GB"
		COL max_allocated_gb FORM 999,999,999.99 HEAD "Max|Allocated GB"
		COL used_percentage FORM 999.99 HEAD "Used|Percentage"
        WITH free_space AS (SELECT c.con_id,cf.tablespace_name,SUM(cf.bytes)/1024/1024/1024 AS free_space_gb FROM cdb_free_space cf JOIN v\$containers c ON cf.con_id = c.con_id GROUP BY c.con_id,cf.tablespace_name ),allocated_space AS (SELECT c.con_id, df.tablespace_name, SUM(df.bytes)/1024/1024/1024 AS allocated_space_gb, MAX(df.maxbytes)/1024/1024/1024 AS max_allocated_gb FROM cdb_data_files df JOIN v\$containers c ON df.con_id = c.con_id GROUP BY c.con_id, df.tablespace_name )SELECT f.con_id,v.name AS con_name,f.tablespace_name,f.free_space_gb,a.allocated_space_gb,a.max_allocated_gb,(a.allocated_space_gb - f.free_space_gb) / a.allocated_space_gb * 100 AS used_percentage FROM free_space f JOIN allocated_space a ON f.con_id = a.con_id AND f.tablespace_name = a.tablespace_name JOIN v\$containers v ON f.con_id = v.con_id WHERE (a.allocated_space_gb - f.free_space_gb) / a.allocated_space_gb * 100 > $THRESHOLD UNION ALL SELECT vc.con_id, vc.name, tf.tablespace_name, NULL AS free_space_gb, SUM(tf.bytes)/1024/1024/1024 AS allocated_space_gb,MAX(tf.maxbytes)/1024/1024/1024 AS max_allocated_gb,NULL AS used_percentage FROM v\$containers vc JOIN cdb_temp_files tf ON vc.con_id = tf.con_id GROUP BY vc.con_id,vc.name, tf.tablespace_name HAVING SUM(tf.bytes)/1024/1024/1024 > 0 ORDER BY 1,2;
        EXIT;
EOF
        # Append threshold warnings to the HTML file
        if [ -s /tmp/tablespace_check.txt ]; then
            echo "<div class='alert'><strong>Warning:</strong> The following tablespaces exceed the $THRESHOLD% usage threshold, Pleaee check!</div>" >> $HTMLFILE
            echo "<pre class='warning'><code>" >> $HTMLFILE
            cat $tempPath/tablespace_check.txt >> $HTMLFILE
            echo "</code></pre>" >> $HTMLFILE
        fi
        rm $tempPath/tablespace_check.txt
    fi

    echo "</code></pre><hr>" >> $HTMLFILE
}


# Function to run SQL script and append results to the HTML file
run_sql_plain()
{
    local sql_query="$1"
    local section_title="$2"
    local check_threshold="$3"

    echo "<h2>$section_title</h2>" >> $HTMLFILE
    echo "<pre><code>" >> $HTMLFILE

    sqlplus -s / as sysdba <<EOF >> $HTMLFILE
	SET PAGESIZE 1000
    SET LINESIZE 200
    SET FEEDBACK OFF
    SET HEADING ON
    $sql_query
    EXIT;
EOF
echo "</code></pre><hr>" >> $HTMLFILE
}


# Function to run SQL script and append results to the HTML file
run_command() {
    local command="$1"
    local section_title="$2"

    echo "<h2>$section_title</h2>" >> $HTMLFILE
    echo "<pre><code>" >> $HTMLFILE
    eval "$command" >> $HTMLFILE
    echo "</code></pre><hr>" >> $HTMLFILE
}


# Function to run SQL script and append results to the HTML file
run_sql_PDB(){
	local sql_query="$1"
    local section_title="$2"
    echo "<h2>$section_title</h2>" >> $HTMLFILE
    echo "<pre><code>" >> $HTMLFILE
    sqlplus -s / as sysdba <<EOF >> $HTMLFILE
	ALTER SESSION SET CONTAINER=VIS;
	$sql_query
	EXIT;
EOF
echo "</code></pre><hr>" >> $HTMLFILE
}



# Function to check URL status
check_url() {
    response=$(curl -o /dev/null -s -w "%{http_code}\n" $url)

    # Check for HTTP status 200 OK
    if [ "$response" -eq 200 ]; then
        echo "Success: The EBS login page is accessible."
    else
        echo "Error: The EBS login page is not accessible. HTTP Status: $response"
    fi
}


# Check the Load Average
loadAverage() {
    load=$(uptime | awk -F'[a-z]:' '{ print $2 }')
    printf "Load Average: $load "
}



# Check the Disk space for the tablespace
diskAlert() {
df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $1 " " $5 }' | while read output;
do
  fs=$(echo $output | awk '{ print $1 }') # Filesystem name
  usep=$(echo $output | awk '{ print $2}' | cut -d'%' -f1 ) # Use percentage without '%'

  if [ $usep -ge $THRESHOLD ]; then
    # If usage is above or equal to the threshold, write an alert in the HTML file
    echo "<div class='alert'><strong>Warning:</strong> The following tablespaces exceed the $THRESHOLD% usage threshold, Pleaee check!</div>" >> $HTMLFILE
    echo "<pre class='warning'><code>" >> $HTMLFILE
  else
    run_command "df -h | grep -v tmpfs" "File System Usage"
  fi
done
}



# Check the CPU utilization
cpu_usage() {
first_reading=$(grep -w "^cpu" /proc/stat)
sleep 1
second_reading=$(grep -w "^cpu" /proc/stat)

read -r -a first_values <<< "$first_reading"
read -r -a second_values <<< "$second_reading"

total_time=0; total_idle=0; total_non_idle=0

for ((i = 1, j = 1; i < ${#first_values[@]}, j < ${#second_values[@]}; i++, j++))
do
    total_time=$((total_time + second_values[j] - first_values[i]))
    if [[ $i -eq 4 || $j -eq 4 || $i -eq 5  || $j -eq 5 ]]; then
        total_idle=$((total_idle + second_values[j] - first_values[i]))
    fi
done

total_non_idle=$((total_time - total_idle))

cpu_usage=$(awk "BEGIN {printf \"%.2f\", ($total_non_idle / $total_time) * 100}")


printf "Total Cores: %s, CPU Precentage: %s\n" "$(nproc)" "$cpu_usage%"
}



# Memory swap check function
mem_swap() {
total=0
for (( i=0; i<1; i++ ))
do
    mem_usage=$(free | awk '/Mem/ {printf "%.2f\n", $3/$2 * 100.0}')
    total=$(awk "BEGIN {print $total + $mem_usage}")
    sleep 1
done

mem_average=$(awk "BEGIN {printf \"%.2f\", $total / 5}")

total=0
for (( i=0; i<1; i++ ))
do
	swap_size=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
	
	if [ "$swap_size" -eq 0 ]; then
		swap_average="Not Enabled"
		break
	else
		swap_average=$(awk "BEGIN {printf \"%.2f\", $total / 5}")%
	fi
	
    swap_usage=$(free | awk '/Swap/ {printf "%.2f\n", $3/$2 * 100.0}')
    total=$(awk "BEGIN {print $total + $swap_usage}")
    sleep 1
done

printf "Memory Percentage: %s, Swap Percentage: %s\n" "$mem_average%" "$swap_average"
}



# HARDLIMITS
hardlimit() {
 echo "Hard Limit: $(ulimit -Hu), Current Usage: $(ps -eLF | wc -l)"
}








# --------------------------------------Main Fuction--------------------------------------
main() {

# Clear previous HTML file
> $HTMLFILE

# adding the style sheet
# genrateStyle


# Check FrontEnd Page Check
run_command "check_url" "EBS Login Page Status"

# Check the Load average on the server
run_command "loadAverage" "Average load on server"



# Database Details
run_sql_plain "select dbid,name,created,log_mode,open_mode from v\$database;" "Database Details"

# Check Instance Details
run_sql_plain " SET LINESIZE 180
				SET PAGESIZE 1000
				COLUMN \"Instance_name\" FORMAT A15
				COLUMN \"host_name\" FORMAT A30
				COLUMN \"version\" FORMAT A15
				COLUMN \"status\" FORMAT A10
				select instance_name,host_name,version,status from v\$instance;" "Instance Details"

# Database Size Details For Both CDB/PDB
run_sql_plain "	COLUMN \"Con ID\" FORMAT 999
				COLUMN \"Database Name\" FORMAT A15
				COLUMN \"TotalSize(GB)\" FORMAT 999.99
				COLUMN \"Total Size of CDB in GB\" FORMAT 999.99

				select con_id \"Con ID\" ,name \"Database Name\",SUM(SIZE_GB) \"TotalSize(GB)\"  from (select  c.con_id,nvl(p.name, 'CDB') name, sum(bytes)/1024/1024/1024 SIZE_GB from  cdb_data_files c, v\$pdbs p where c.con_id=p.con_id(+) GROUP BY c.con_id,name UNION
				select  c.con_id \"Con ID\" ,nvl(p.name, 'CDB') \"Database Name\" , round(sum(bytes)/1024/1024/1024) \"TotalSize(GB)\" from  cdb_temp_files c, v\$pdbs p where c.con_id=p.con_id(+) GROUP BY c.con_id,name)group by con_id,name order by con_id;" "Database Size Details For Both CDB/PDB"

# Check For DataFiles Details For Both CDB/PDB
run_sql_plain " SET LINESIZE 180
				SET PAGESIZE 1000
				COLUMN \"CONTAINER_NAME\" FORMAT A20
				COLUMN \"TABLESPACE_NAME\" FORMAT A20
				COLUMN \"FILE_NAME\" FORMAT A70
				COLUMN \"STATUS\" FORMAT A10
				COLUMN \"AUTOEXTEND\" FORMAT A10
				SELECT CASE WHEN d.CON_ID = 1 THEN 'CDB$ROOT' ELSE p.PDB_NAME END AS \"CONTAINER_NAME\", d.TABLESPACE_NAME, d.FILE_NAME,d.status as \"STATUS\",d.AUTOEXTENSIBLE as \"AUTOEXTEND\" FROM CDB_DATA_FILES d LEFT JOIN CDB_PDBS p ON d.CON_ID = p.PDB_ID ORDER BY CONTAINER_NAME, d.FILE_ID;" "DataFiles Details For Both CDB/PDB"				

# Check Tablespace Usage
run_sql_1 " WITH free_space AS ( SELECT c.con_id, cf.tablespace_name, SUM(cf.bytes)/1024/1024/1024 AS free_space_gb FROM cdb_free_space cf JOIN v\$containers c ON cf.con_id = c.con_id GROUP BY c.con_id, cf.tablespace_name ), allocated_space AS ( SELECT c.con_id, df.tablespace_name, SUM(df.bytes)/1024/1024/1024 AS allocated_space_gb, MAX(df.maxbytes)/1024/1024/1024 AS max_allocated_gb FROM cdb_data_files df JOIN v\$containers c ON df.con_id = c.con_id GROUP BY c.con_id, df.tablespace_name )SELECT f.con_id,v.name AS con_name, f.tablespace_name,f.free_space_gb, a.allocated_space_gb, a.max_allocated_gb FROM free_space f JOIN allocated_space a ON f.con_id = a.con_id AND f.tablespace_name = a.tablespace_name JOIN v\$containers v ON f.con_id = v.con_id UNION ALL SELECT vc.con_id, vc.name,tf.tablespace_name,NULL AS free_space_gb,SUM(tf.bytes)/1024/1024/1024 AS allocated_space_gb,MAX(tf.maxbytes)/1024/1024/1024 AS max_allocated_gb FROM v\$containers vc JOIN cdb_temp_files tf ON vc.con_id = tf.con_id GROUP BY vc.con_id, vc.name, tf.tablespace_name ORDER BY 1, 2;" "Tablespace Usage" "true"


# Check Database Resource Utilization
run_sql_plain " SET LINESIZE 300
				SET PAGESIZE 50
				COLUMN \"RESOURCE_NAME\" FORMAT A30
				COLUMN \"CURRENT_UTILIZATION\" FORMAT 999
				COLUMN \"MAX_UTILIZATION\" FORMAT 999
				COLUMN \"INITIAL_ALLOCATION\" FORMAT 999
				COLUMN \"LIMIT_VALUE\" FORMAT 999
				select RESOURCE_NAME, CURRENT_UTILIZATION , MAX_UTILIZATION, INITIAL_ALLOCATION, LIMIT_VALUE FROM v\$resource_limit where RESOURCE_NAME in ('processes','sessions','parallel_max_servers','enqueue_resources');" "Database Resource Utilization"


# Archive Generation Per Day
run_sql_plain " SET LINESIZE 300
		        SET PAGESIZE 50
		        COLUMN \"DAY\" FORMAT A30
		        COLUMN \"GB\" FORMAT 9999.99
		        COLUMN \"ARCHIVES_GENERATED_PER_DAY\" FORMAT 9999.99
		        SELECT TRUNC(COMPLETION_TIME, 'DD') AS \"DAY\",ROUND(SUM(BLOCKS * BLOCK_SIZE) / 1024 / 1024 / 1024) AS \"GB\",COUNT(*) AS \"ARCHIVES_GENERATED_PER_DAY\" FROM v\$ARCHIVED_LOG WHERE COMPLETION_TIME > SYSDATE-6 GROUP BY TRUNC(COMPLETION_TIME, 'DD')ORDER BY 1 DESC;" "Archive Generation Per Day"


# Usage Of Temp Tablespace Usage
run_sql_plain "	SET LINESIZE 150
				SET PAGESIZE 1000
				COLUMN \"Tablespace Name\" FORMAT A10
				COLUMN \"TotalSize(GB)\" FORMAT 9999999.99
				COLUMN \"UsedSize(GB)\" FORMAT 9999999.99
				select A.tablespace_name As \"Tablespace Name\",D.mb_total AS \"TotalSize(GB)\",SUM(A.used_blocks*D.block_size)/1024/1024/1024 \"UsedSize(GB)\" FROM v\$sort_segment A,(SELECT B.name, C.block_size block_size,SUM (C.bytes)/1024/1024/1024 mb_total FROM v\$tablespace B, v\$tempfile C
				WHERE B.ts#= C.ts# GROUP BY B.name, C.block_size ) D WHERE A.tablespace_name = D.name GROUP by A.tablespace_name, D.mb_total;" "Usage Of Temp Tablespace Usage"


# Check For Block Corruption Information 
run_sql_plain "select FILE#,BLOCK#,BLOCKS,CORRUPTION_CHANGE#,CORRUPTION_TYPE FROM v\$database_block_corruption order by FILE# desc;" "Block Corruption Information"


# Total Invalid Objects in Database
run_sql_plain " SET LINESIZE 150
				SET PAGESIZE 1000
				COLUMN \"OWNER\" FORMAT A10
				COLUMN \"OBJECT_NAME\" FORMAT A40
				COLUMN \"OBJECT_TYPE\" FORMAT A40
				COLUMN \"LAST_DDL_RUN\" FORMAT A30
				select Owner AS \"OWNER\",Object_name AS \"OBJECT_NAME\",object_type AS \"OBJECT_TYPE\",last_ddl_time AS \"LAST_DDL_RUN\" from dba_objects where status = 'INVALID';" "Total Invalid Objects in CDB Database"


# List of Online users
run_sql_plain " set lines 132
				col user_name format a32
				col description format a50
				SELECT DISTINCT icx.session_id,
				icx.user_id,
				fu.user_name,
				fu.description
				FROM icx_sessions icx, fnd_user fu
				WHERE disabled_flag != 'Y'
				AND icx.pseudo_flag = 'N'
				AND (last_connect +
				DECODE (fnd_profile.VALUE ('ICX_SESSION_TIMEOUT'),
				NULL, limit_time,
				0 , limit_time,
				fnd_profile.VALUE ('ICX_SESSION_TIMEOUT')/60) / 24) > SYSDATE
				AND icx.counter < limit_connects
				AND icx.user_id = fu.user_id
				AND fu.user_name!='GUEST';
				" "Total Number of Online users"




# Total count of Online Users
run_sql_plain " SELECT DISTINCT count (*)
				FROM icx_sessions icx, fnd_user fu
				WHERE disabled_flag != 'Y'
				AND icx.pseudo_flag = 'N'
				AND (last_connect + 
				DECODE (fnd_profile.VALUE ('ICX_SESSION_TIMEOUT'),
				NULL, limit_time,
				0 , limit_time,
				fnd_profile.VALUE ('ICX_SESSION_TIMEOUT')/60) / 24) > SYSDATE
				AND icx.counter < limit_connects
				AND icx.user_id = fu.user_id
				AND fu.user_name!='GUEST';
				" "Total count of Online users"


# Inactive Sessions Summary (More than 24 Hours)			
run_sql_plain "	SET LINESIZE 250
				SET PAGESIZE 2000
				COLUMN \"SID\" FORMAT 99999
				COLUMN \"SERIAL#\" FORMAT 99999
				COLUMN \"STATUS\" FORMAT A10
				COLUMN \"MODULE\" FORMAT A60
				COLUMN \"PROGRAM\" FORMAT A60
				COLUMN \"MACHINE\" FORMAT A50
				COLUMN \"COUNT\" FORMAT 99999
				select SID,SERIAL#,STATUS,module,program,machine, count(*) from v\$session where status='INACTIVE' and username='APPS' and last_call_et > (60*60*24) group by module,program,machine,SID,SERIAL#,STATUS order by count(*) desc;" "Inactive Sessions Summary (More than 24 Hours)"


# Database RMAN Backup Summary 
run_sql_plain "	SET LINESIZE 150
				SET PAGESIZE 1000
				COLUMN \"SESSION_KEY\" FORMAT 999999999999999
				COLUMN \"START_TIME\" FORMAT A30
				COLUMN \"END_TIME\" FORMAT A30
				COLUMN \"STATUS\" FORMAT A15
				COLUMN \"AUTOBACKUP_DONE\" FORMAT A5
				COLUMN \"AUTOBACKUP_COUNT\" FORMAT 999
				COLUMN \"INPUT_TYPE FORMAT\" FORMAT A15
				COLUMN \"ELAPSED_SECONDS\" FORMAT 99999
				SELECT SESSION_KEY,TO_CHAR(START_TIME, 'DD-MON-YYYY HH24:MI:SS') AS START_TIME,TO_CHAR(END_TIME, 'DD-MON-YYYY HH24:MI:SS') AS END_TIME,STATUS,AUTOBACKUP_DONE,AUTOBACKUP_COUNT,INPUT_TYPE,ELAPSED_SECONDS FROM V\$RMAN_BACKUP_JOB_DETAILS WHERE START_TIME > SYSDATE - 5 ORDER BY START_TIME DESC;" "Database RMAN Backup Summary "

# Database Alert Log Errors
run_sql_plain "	SET LINESIZE 700
				SET PAGESIZE 1200
				COLUMN \"TIMESTAMP\" FORMAT A30
				COLUMN \"message_text\" FORMAT A500
				select TO_CHAR(originating_timestamp, 'DD-MON-YYYY HH24:MI:SS') AS \"TIMESTAMP\", message_text FROM x\$dbgalertext WHERE originating_timestamp > (sysdate - 12/24) AND message_text LIKE '%ORA-%' ORDER BY originating_timestamp;" "Database Alert Log Errors"

# Recovery Dest Size & Space Use By Archivelogs
run_sql_plain " SET LINESIZE 300
				SET PAGESIZE 50
				COLUMN \"NAME\" FORMAT A20
				COLUMN \"TOTAL_SPACE_GB\" FORMAT 999999
				COLUMN \"USED_SPACE_GB\" FORMAT 99999
				COLUMN \"FREE_SPACE_GB\" FORMAT 99999
				SELECT NAME AS \"NAME\",(SPACE_LIMIT / 1024 / 1024 / 1024) AS \"TOTAL_SPACE_GB\",(SPACE_USED / 1024 / 1024 / 1024) AS \"USED_SPACE_GB\", ROUND((SPACE_LIMIT / 1024 / 1024 / 1024)-(SPACE_USED / 1024 / 1024 / 1024)) AS \"FREE_SPACE_GB\"
				FROM V\$RECOVERY_FILE_DEST;" "Recovery Dest Size & Space Use By Archivelogs"




# --------------------------------------query on PDB--------------------------------------

# Total Invalid Objects in PDB Database
run_sql_PDB "   SET LINESIZE 150
				SET PAGESIZE 1000
				COLUMN \"OWNER\" FORMAT A10
				COLUMN \"OBJECT_NAME\" FORMAT A40
				COLUMN \"OBJECT_TYPE\" FORMAT A40
				COLUMN \"LAST_DDL_RUN\" FORMAT A30
				select Owner AS \"OWNER\",Object_name AS \"OBJECT_NAME\",object_type AS \"OBJECT_TYPE\",last_ddl_time AS \"LAST_DDL_RUN\" from dba_objects where status = 'INVALID';" "Total Invalid Objects in PDB Database"

# EBS Application Concurrent Manager Status
run_sql_PDB "	SET LINESIZE 150
				SET PAGESIZE 1000
				COLUMN  \"CONCURRENT MANAGER\" FORMAT A53
				COLUMN \"SERVER NODE\" FORMAT A30
				COLUMN \"ACTUAL\" FORMAT 999
				COLUMN \"TARGET\" FORMAT 999
				COLUMN \"STATUS\" FORMAT A30
				SELECT DISTINCT B.USER_CONCURRENT_QUEUE_NAME \"CONCURRENT MANAGER\",A.TARGET_NODE \"SERVER NODE\",A.RUNNING_PROCESSES \"ACTUAL\",A.MAX_PROCESSES \"TARGET\", DECODE(B.CONTROL_CODE,'D', 'DEACTIVATING','E', 'DEACTIVATED','N', 'NODE UNAVAILABLE','A', 'ACTIVATING','X', 'TERMINATED','T', 'TERMINATING','V', 'VERIFYING','O', 'SUSPENDING','P', 'SUSPENDED','Q', 'RESUMING','R', 'RESTARTING') AS \"STATUS\" FROM APPS.FND_CONCURRENT_QUEUES A,APPS.FND_CONCURRENT_QUEUES_VL B WHERE A.CONCURRENT_QUEUE_ID = B.CONCURRENT_QUEUE_ID AND A.RUNNING_PROCESSES = A.MAX_PROCESSES ORDER BY A.MAX_PROCESSES DESC;" "EBS Application Concurrent Manager Status"

# Long Runnig Concurrent Request From Last One Hour
run_sql_PDB "	SET LINESIZE 180
				SET PAGESIZE 2200
				COLUMN \"REQUESTID\" FORMAT 999999999
				COLUMN \"USERNAME\" FORMAT A10
				COLUMN \"RESPONSIBILITY_NAME\" FORMAT A25
				COLUMN \"PROGRAM_NAME\" FORMAT A40
				COLUMN \"START_DATETIME\" FORMAT A25
				COLUMN \"STATUS\" FORMAT A10
				COLUMN \"RUNTIME_MIN\" FORMAT 999999.99
				COLUMN \"REPORT_ARGUMENTS\" FORMAT A40
				SELECT DISTINCT REQUESTID,USERNAME,RESPONSIBILITY_NAME,PROGRAM_NAME,START_DATETIME,STATUS,RUNTIME_MIN,REPORT_ARGUMENTS from (SELECT FCR.REQUEST_ID AS \"REQUESTID\",FU.USER_NAME AS \"USERNAME\",FR.RESPONSIBILITY_NAME AS \"RESPONSIBILITY_NAME\",FCP.USER_CONCURRENT_PROGRAM_NAME AS \"PROGRAM_NAME\",TO_CHAR (FCR.ACTUAL_START_DATE, 'DD-MON-YYYY HH24:MI:SS') AS \"START_DATETIME\",DECODE (FCR.STATUS_CODE, 'R', 'R:RUNNING', FCR.STATUS_CODE) AS \"STATUS\",ROUND (((SYSDATE - FCR.ACTUAL_START_DATE) * 60 * 24), 2) AS \"RUNTIME_MIN\",FCR.ARGUMENT_TEXT AS \"REPORT_ARGUMENTS\" FROM APPS.FND_CONCURRENT_REQUESTS FCR,APPS.FND_USER FU ,APPS.FND_RESPONSIBILITY_VL FR ,APPS.FND_CONCURRENT_PROGRAMS_VL FCP WHERE FCR.STATUS_CODE LIKE 'R' AND FU.USER_ID = FCR.REQUESTED_BY AND FR.RESPONSIBILITY_ID = FCR.RESPONSIBILITY_ID AND FCR.CONCURRENT_PROGRAM_ID = FCP.CONCURRENT_PROGRAM_ID AND FCR.PROGRAM_APPLICATION_ID = FCP.APPLICATION_ID AND ROUND (((SYSDATE - FCR.ACTUAL_START_DATE) * 60 * 24), 2) > 60 ORDER BY FCR.CONCURRENT_PROGRAM_ID,REQUEST_ID DESC);" "Long Runnig Concurrent Request From Last One Hour"

# Request Completed With Warning & Error (Past 12 Hour)
run_sql_PDB "	SET LINESIZE 250
				SET PAGESIZE 1000
				COLUMN \"PROGRAM_NAME\" FORMAT A50
				COLUMN \"STATUS\" FORMAT A10
				COLUMN \"ERROR MESSAGE\" FORMAT A150
				COLUMN \"START_DATE\" FORMAT A15
				COLUMN \"COUNT\" FORMAT 9999
				select DECODE(FCP.USER_CONCURRENT_PROGRAM_NAME,'Report Set', FCR.DESCRIPTION,FCP.USER_CONCURRENT_PROGRAM_NAME) \"PROGRAM_NAME\",DECODE(FCR.STATUS_CODE,'E','ERROR','G','WARNING') \"STATUS\",FCR.COMPLETION_TEXT \"ERROR MESSAGE\" ,FCR.ACTUAL_START_DATE \"START_DATE\" ,COUNT(*) \"COUNT\" from APPS.FND_CONCURRENT_REQUESTS FCR, APPS.FND_CONCURRENT_PROGRAMS_TL FCP WHERE FCR.CONCURRENT_PROGRAM_ID=FCP.CONCURRENT_PROGRAM_ID AND FCR.STATUS_CODE in ('E','G') AND FCP.LANGUAGE = 'US' AND  REQUESTED_START_DATE > sysdate - 12/24 GROUP BY FCP.USER_CONCURRENT_PROGRAM_NAME, FCR.DESCRIPTION,FCP.USER_CONCURRENT_PROGRAM_NAME,DECODE(FCP.USER_CONCURRENT_PROGRAM_NAME,'Report Set',FCR.DESCRIPTION,FCP.USER_CONCURRENT_PROGRAM_NAME),DECODE(FCR.STATUS_CODE,'E','ERROR','G','WARNING'), FCR.COMPLETION_TEXT,FCR.ACTUAL_START_DATE ORDER by count(*) desc;" "Request Completed With Warning & Error (Past 12 Hour)"

# Concurrent Requests Summary (Past 12 Hours)
run_sql_PDB "	SET LINESIZE 300
				SET PAGESIZE 50
				COLUMN \"STATUS\" FORMAT A120
				COLUMN \"COUNT\" FORMAT 999999
				select decode(phase_code,'R','Running','I','Inactive','C','Completed','P','Pending')||' With '|| decode(status_code,'D','Cancelled', 'U','Disabled', 'E','Error', 'M','NoManager', 'R','Normal', 'I','Normal', 'C','Normal', 'H','OnHold', 'W','Paused', 'B','Resuming', 'P','Scheduled', 'Q','Standby', 'S','Suspended', 'X','Terminated', 'T','Terminating', 'A','Waiting', 'Z','Waiting', 'G','Warning') \"STATUS\",	Count(*) \"COUNT\" from apps.fnd_concurrent_requests where REQUESTED_START_DATE > sysdate - 12/24 group by phase_code,status_code order by decode(phase_code,'R','Running','I','Inactive','C','Completed','P','Pending'),count(*) desc;" "Concurrent Requests Summary (Past 12 Hours)"							

# Gather Schema Statistics Last Run
run_sql_PDB "	SET LINESIZE 350
				SET PAGESIZE 1500
				COLUMN \"REQUESTID\" FORMAT 99999999999
				COLUMN \"PROGRAM_NAME\" FORMAT A30
				COLUMN \"PROCESS_TIME\" FORMAT 9999
				COLUMN \"REQUESTDATE\" FORMAT A20
				COLUMN \"STARTDATE\" FORMAT A20
				COLUMN \"COMPLETEDATE\" FORMAT A20
				COLUMN \"USERNAME\" FORMAT A15
				COLUMN \"PHASECODE\" FORMAT A10
				COLUMN \"STATUSCODE\" FORMAT A10
				COLUMN \"PROGRAM-ARG\" FORMAT A50
				SELECT DISTINCT a.request_id \"REQUESTID\",c.USER_CONCURRENT_PROGRAM_NAME \"PROGRAM_NAME\",round(((a.actual_completion_date-a.actual_start_date)*24*60*60/60),2) AS \"PROCESS_TIME\",To_Char(a.request_date,'DD-MON-YY HH24:MI:SS') \"REQUESTDATE\",To_Char(a.actual_start_date,'DD-MON-YY HH24:MI:SS') \"STARTDATE\",To_Char(a.actual_completion_date,'DD-MON-YY HH24:MI:SS')\"COMPLETEDATE\",d.user_name \"USERNAME\" , DECODE(a.phase_code,'P', 'Pending','R', 'Running','C', 'Completed','I', 'Inactive','B', 'Blocked','G', 'Waiting','H', 'On Hold','E', 'Error','D', 'Cancelled','Q', 'Standby','Z', 'Paused','Unknown Phase')\"PHASECODE\",DECODE(a.status_code,'A', 'Waiting','B', 'Resuming','C', 'Normal','D', 'Cancelled','E', 'Error','F', 'Scheduled','G', 'Warning','H', 'On Hold','I', 'Normal','M', 'No Manager','Q', 'Standby','S', 'Suspended','T', 'Terminating','U', 'Disabled','W', 'Paused','X', 'Terminated','Z', 'Waiting','Unknown Status')\"STATUSCODE\",a.argument_text \"PROGRAM-ARG\" FROM   apps.fnd_concurrent_requests a,apps.fnd_concurrent_programs b ,apps.FND_CONCURRENT_PROGRAMS_TL c,apps.fnd_user d WHERE a.concurrent_program_id= b.concurrent_program_id AND b.concurrent_program_id=c.concurrent_program_id AND a.requested_by =d.user_id AND trunc(a.actual_completion_date) > SYSDATE - 30 AND c.USER_CONCURRENT_PROGRAM_NAME='Gather Schema Statistics' and argument_text like  '%,%,%,%,%,%,%,%,%' ORDER BY REQUEST_ID DESC;" "Gather Schema Statistics Last Run"							

# EBS Application Profiles Changed In Last Two Days
run_sql_PDB "	SET LINESIZE 250
				SET PAGESIZE 1000
				COLUMN \"Profile Option\" FORMAT A50
				COLUMN \"Option Level\" FORMAT A20
				COLUMN \"Profile Value\" FORMAT A50
				COLUMN \"ChangeDate\" FORMAT A15
				COLUMN \"UserName\" FORMAT A15
				select DISTINCT \"Profile Option\",\"Option Level\",\"Profile Value\",\"ChangeDate\",\"UserName\" from (select tl.user_profile_option_name \"Profile Option\",decode(val.level_id,10001, 'Site',10002, 'Application',10003, 'Responsibility',10004, 'User',10005, 'Server',10006, 'Organization',10007, 'Server+Resp','No idea, boss') \"Option Level\",val.profile_option_value \"Profile Value\",val.last_update_date \"ChangeDate\",usr.user_name \"UserName\" from apps.fnd_profile_options opt,apps.fnd_profile_option_values val,apps.fnd_profile_options_tl tl,apps.fnd_user usr where opt.profile_option_id = val.profile_option_id
				and opt.profile_option_name = tl.profile_option_name and usr.user_id = val.last_updated_by order by val.last_update_date desc )where rownum <= 2;" "EBS Application Profiles Changed In Last Two Days"

# Workflow Components Service Status
run_sql_PDB "	SET LINESIZE 250
				SET PAGESIZE 1000
				COLUMN \"COMPONENT_TYPE\" FORMAT 9999999
				COLUMN \"COMPONENT_NAME\" FORMAT A50
				COLUMN \"COMPONENT_STATUS\" FORMAT A10
				SELECT DISTINCT fsc.COMPONENT_ID \"COMPONENT_ID\",fsc.component_name \"COMPONENT_NAME\",fsc.COMPONENT_STATUS \"STATUS\",fcq.ENABLED_FLAG \"ENABLED\",fsc.INBOUND_AGENT_NAME \"INBOUND_AGENT_NAME\",fsc.OUTBOUND_AGENT_NAME \"OUTBOUND_AGENT_NAME\",fsc.STARTUP_MODE \"STARTUP_MODE\",fsc.LAST_UPDATE_DATE \"UPDATED\" FROM apps.fnd_svc_components fsc LEFT OUTER JOIN apps.fnd_svc_comp_param_vals_v v ON v.component_id = fsc.component_id LEFT OUTER JOIN apps.fnd_svc_comp_params_b p ON v.parameter_id = p.parameter_id LEFT OUTER JOIN apps.FND_CONCURRENT_QUEUES_VL fcq ON fsc.concurrent_queue_id = fcq.concurrent_queue_id LEFT OUTER JOIN apps.FND_CP_SERVICES fcs ON fcq.MANAGER_TYPE = fcs.SERVICE_ID LEFT OUTER JOIN apps.FND_CONCURRENT_PROCESSES fcp ON fcq.concurrent_queue_id = fcp.concurrent_queue_id AND fcq.application_id = fcp.queue_application_id AND fcp.process_status_code = 'A' WHERE fsc.COMPONENT_TYPE!='FND_MCS_PUSH_NTF_PROVIDER' AND fcs.SERVICE_HANDLE='FNDCPGSC' AND v.PARAMETER_NAME='PROCESSOR_IN_THREAD_COUNT' and fsc.ZD_SYNC='UPDATED';" "Workflow Components Service Status"
				
# WORKFLOW NOTIFICATION MAILER
run_sql_PDB "	SET LINESIZE 300
				SET PAGESIZE 50
				COLUMN \"COMPONENT_NAME\" FORMAT A40
				COLUMN \"COMPONENT_STATUS\" FORMAT A20
				SELECT component_name AS \"COMPONENT_NAME\",CASE WHEN component_status = 'RUNNING' THEN 'RUNNING' ELSE 'DOWN' END AS \"COMPONENT_STATUS\" FROM apps.fnd_svc_components WHERE component_type = 'WF_MAILER' and ZD_SYNC='UPDATED';" "Workflow Notification Mailer Status"				






#--------------------------------------Os health check for db tier--------------------------------------

# Disk Space
run_command "df -h | grep -v tmpfs" "File System Usage"


# CPU utilization
run_command "cpu_usage" "Total Cores CPU Percentage"

# Memory swap
run_command "mem_swap" "Memory Swap Percentage"

# Server uptime
run_command "uptime -p" "Server Uptime"

# Current User
run_command "who -uH | column -t" "Current Logged-on Users"


# Formatting the TOP command output
export PS_FORMAT="ruser,pid,ppid,nice,wchan:25,pmem,pcpu,time:15,euser,state=STATE,flags=FLAGS,stime,thcount,comm:25"

# TOP (CPU processes)
run_command "ps -eo \"$PS_FORMAT\" --sort=-pcpu | head -5" "Top CPU Consuming Processes"

# TOP (Memory processes)
run_command "ps -e --sort=-pmem | grep -v grep | head -5" "Top Memory Consuming Processes"

# TOP (Zombie Proceses)
run_command "ps -e | grep Z | grep -v ps" " Zombie Processes "


# SMON and tnslsnr
run_command "ps -e | head -1; ps -e | grep -v ps | grep -wE 'smon|tnslsnr'" " Business Specific Processes "

# Processes and Threads Counts
run_command "hardlimit" "Current Processes/Threads Count"


}



# Main execution block
main




# ---------------------------------------------Footer---------------------------------------------------------
# End of HTML document
echo "<hr><p>Health check completed. Review the sections above for detailed information.</p>" >> $HTMLFILE
echo "</body></html>" >> $HTMLFILE

echo "Health check completed. Check the HTML file for details: $HTMLFILE"