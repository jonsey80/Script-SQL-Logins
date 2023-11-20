# Script-SQL-Logins
Power Shell Script to document all SQL logins and permissions - use for migrations and/or backup

To use this file navigate to the bottom of the script "Script Logins" and find the following variables:

$server_to_script: Enter the connection details for the instance you want to run against
$file_location: Enter the location of a pre-made folder you want the login scripts to be generated 
$azure_AD: y/n for running againt an Azure instance which is not federated with on prem AD

To import generation login scripts run "Run Login Scripts" 
$fileslocation: this is where the login scrips are located
$server = the instance you wish to import the login's to 

