#!/bin/bash

tempPath='/home/oracle/alertScript'
. /u01/oracle/19c/dbhome/CDBVIS_test.env




# HTML output file for the health check
HTMLFILE="/home/oracle/alertScript/log/HEALTH_CHECK_REPORT_FOR_$(hostname)_$(date +%Y%m%d_%H%M%S).html"

# Threshold for tablespace usage
THRESHOLD=90

# EBS Login URL
url="http://test.jupiter.com:8050/OA_HTML/AppsLogin.jsp"


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


main() {

# Check Tablespace Usage
run_sql_1 " WITH free_space AS ( SELECT c.con_id, cf.tablespace_name, SUM(cf.bytes)/1024/1024/1024 AS free_space_gb FROM cdb_free_space cf JOIN v\$containers c ON cf.con_id = c.con_id GROUP BY c.con_id, cf.tablespace_name ), allocated_space AS ( SELECT c.con_id, df.tablespace_name, SUM(df.bytes)/1024/1024/1024 AS allocated_space_gb, MAX(df.maxbytes)/1024/1024/1024 AS max_allocated_gb FROM cdb_data_files df JOIN v\$containers c ON df.con_id = c.con_id GROUP BY c.con_id, df.tablespace_name )SELECT f.con_id,v.name AS con_name, f.tablespace_name,f.free_space_gb, a.allocated_space_gb, a.max_allocated_gb FROM free_space f JOIN allocated_space a ON f.con_id = a.con_id AND f.tablespace_name = a.tablespace_name JOIN v\$containers v ON f.con_id = v.con_id UNION ALL SELECT vc.con_id, vc.name,tf.tablespace_name,NULL AS free_space_gb,SUM(tf.bytes)/1024/1024/1024 AS allocated_space_gb,MAX(tf.maxbytes)/1024/1024/1024 AS max_allocated_gb FROM v\$containers vc JOIN cdb_temp_files tf ON vc.con_id = tf.con_id GROUP BY vc.con_id, vc.name, tf.tablespace_name ORDER BY 1, 2;" "Tablespace Usage" "true"


}


main



# ---------------------------------------------Footer---------------------------------------------------------
# End of HTML document
echo "<hr><p>Health check completed. Review the sections above for detailed information.</p>" >> $HTMLFILE
echo "</body></html>" >> $HTMLFILE

echo "Health check completed. Check the HTML file for details: $HTMLFILE"