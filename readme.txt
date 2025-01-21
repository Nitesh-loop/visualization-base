Project Directory: C:\Users\91865\Documents\Nitesh\OfficeDoc\EPCCO\Visualization\base

#git setup:
git init
git remote add origin https://github.com/Nitesh-loop/web-project-react.git
git config user.email "<Email_required>"
git config user.name "<user_id_required>"
git add .
git commit -m "Initial commit"
git push -u origin main


# Display the html on server using export display command:
# on remote session:
export DISPLAY=:0

firefox /home/oracle/alertScript/log/HEALTH_CHECK_REPORT_FOR_test.jupiter.com_20250121_115450.html