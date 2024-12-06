#!/bin/bash
CSV_DIR=~/guvi_project/csv
LOG_FILE=~/guvi_project/logs/upload.log
DB_NAME=amoldatta
TABLE_NAME=sales_data
BACKUP_DIR=~/guvi_project/backup

# Loop through all CSV files in the directory
for file in $CSV_DIR/*.csv; do
    echo "Processing $file..." >> $LOG_FILE
    psql -d $DB_NAME -c "\COPY $TABLE_NAME FROM '$file' WITH CSV HEADER;"

    if [ $? -eq 0 ]; then
        echo "Uploaded $file successfully." >> $LOG_FILE
        
        # Check if hard link already exists
        if [ ! -e $BACKUP_DIR/$(basename $file) ]; then
            ln $file $BACKUP_DIR/$(basename $file)  # Create a hard link only if it doesn't already exist
            echo "Hard link created for $file." >> $LOG_FILE
        else
            echo "Hard link for $file already exists." >> $LOG_FILE
        fi

        # Run SQL queries for automation
        psql -d $DB_NAME -c "
            -- Query 1: Identify average customer visit in the type B store in April Months
            SELECT AVG(sales) 
            FROM $TABLE_NAME
            WHERE store_type = 'B' AND date >= '2024-04-01' AND date <= '2024-04-30';
        " >> $LOG_FILE

        psql -d $DB_NAME -c "
            -- Query 2: Identify the best average sales in the holiday week for all store types
            SELECT store_type, AVG(sales)
            FROM $TABLE_NAME
            WHERE holiday = TRUE
            GROUP BY store_type
            ORDER BY AVG(sales) DESC
            LIMIT 1;
        " >> $LOG_FILE

        psql -d $DB_NAME -c "
            -- Query 3: What is the expected sales of each department when unemployment factor is greater than 8
            SELECT department_id, AVG(sales) 
            FROM $TABLE_NAME
            WHERE unemployment > 8
            GROUP BY department_id;
        " >> $LOG_FILE
    else
        echo "Error uploading $file." >> $LOG_FILE
    fi
done

# Send email alert
echo -e "Subject: CSV Upload Completion\n\nCSV files processed successfully. Check the logs for details." | msmtp amoldattatray@iitmpravaratak.net

if [ $? -eq 0 ]; then
    echo "Email sent successfully." >> $LOG_FILE
else
    echo "Error sending email." >> $LOG_FILE
fi

#comment check debug