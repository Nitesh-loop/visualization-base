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
        margin-bottom: 10px;
    }
    h2 {
        color: #333;
        border-bottom: 2px solid #0056b3;
        padding-bottom: 5px;
        margin-top: 30px;
        margin-bottom: 10px;
    }
    pre {
        background-color: #e9ecef;
        padding: 10px;
        border-radius: 5px;
        overflow-x: auto;
        border: 1px solid #ccc;
    }
    code {
        font-family: Consolas, 'Courier New', Courier, monospace;
        font-size: 14px;
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
        background-color: #fff8f0;
        border: 1px solid #d8000c;
    }
    p {
        font-size: 14px;
        line-height: 1.5;
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
run_sql_PDB() {
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
genrateStyle


# --------------------------------------query on PDB--------------------------------------




#--------------------------------------Advance Parameters--------------------------------------

# Show SGA
run_sql_plain   "   SET LINESIZE 150
                    SET PAGESIZE 1000
                    COLUMN "NAME" FORMAT A50
                    COLUMN "TYPE" FORMAT A25
                    COLUMN "VALUE" FORMAT A50
                    SHOW PARAMETER SGA;
                " "SGA Values "

# Show PGA
run_sql_plain   "   SET LINESIZE 150
                    SET PAGESIZE 1000
                    COLUMN "NAME" FORMAT A50
                    COLUMN "TYPE" FORMAT A25
                    COLUMN "VALUE" FORMAT A50
                    SHOW PARAMETER PGA;
                " "PGA Values "

# Show PROCESSES
run_sql_plain   "   SET LINESIZE 150
                    SET PAGESIZE 1000
                    COLUMN "NAME" FORMAT A50
                    COLUMN "TYPE" FORMAT A25
                    COLUMN "VALUE" FORMAT A50
                    SHOW PARAMETER PROCESSES;
                " "Processes Values "



# Alert Log and Trace Files
run_command "tail -n 30 /u01/oracle/19c/diag/rdbms/cdbvis/CDBVIS/trace/alert_CDBVIS.log" " Alert Log"

# Redo log files:
run_sql_plain "     SET LINESIZE 150
                    SET PAGESIZE 1000
                    COLUMN "GROUP" FORMAT A50
                    COLUMN "MEMBER" FORMAT A50
                    SELECT GROUP#, MEMBER FROM v\$logfile;
            " "Redo log files"


# WebLogic Server Monitoring
run_command "ps -ef | grep oacore_server | grep -v grep | wc -l" "Admin server status for Oacore"

run_command "ps -ef | grep forms_server | grep -v grep | wc -l" "Admin server status for forms"

run_command "ps -ef | grep oafm_server | grep -v grep | wc -l" "Admin server status for Oafm"


# weblogic admin server webpage return status
run_command "curl -L -o /dev/null -s -w \"%{http_code}\n\" http://test.jupiter.com:7052/console" "Admin server webpage return status"




#--------------------------------------Os health check for db tier--------------------------------------



# Check for open ports and connections on the system:
run_command " netstat -tuln | grep -E '7052|8050|1571' " "open ports and connections "

# Monitor disk performance and I/O stats:
run_command "sar -pd 2 5|grep Average" "Average of Disk performance"

# VMSTAT output
run_command "vmstat -t -w -S M 2 4 -y | sed '1,2d' | column -t -N Run,Block,Swap,FreeMem,BuffMem,CacheMem,SwpIn,SwpOut,BlkIn,BlkOut,Int,CtxSwtch,Usr,Sys,Idle,Wait,Steal,Date,Time" "VMSTAT output"

}



# Main execution block
main




# ---------------------------------------------Footer---------------------------------------------------------
# End of HTML document
echo "<hr><p>Health check completed. Review the sections above for detailed information.</p>" >> $HTMLFILE
echo "</body></html>" >> $HTMLFILE

echo "Health check completed. Check the HTML file for details: $HTMLFILE"