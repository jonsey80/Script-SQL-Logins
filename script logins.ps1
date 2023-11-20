############################################################################################
#                                                                                          #
#Author: M Jones                                                                           #
#Date: 27/02/2020                                                                          #
#Version: 1.0                                                                              #
#Details: Downloads the script to create all login and users on a server                   #                                                                   
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  #
# Version      Author        Date        Notes                                             #
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  #
#  1.0         M Jones       27/02/2020  Initial Script                                    #
#  2.0         M Jones       26/01/2023  Re-write to handle user defined group permissions #
#                                        & Azure logins                                    #
#  2.1         M Jones       29/06/2023  Bug fixes                                         #
#  2.2         M Jones       17/07/2023  Add Oject Permissions                             #
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  #
############################################################################################


function Get-TimeStamp {
    
    return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date)
  } 
  
   

  function get_usergroups($server) {

  #find list of databases within the instance
  $db = Invoke-Sqlcmd -ServerInstance $server -query $system_databases
  #iterate through the databases 
  foreach ($t in $db.name) {

   #find all user groups within the database 
   $dbrole = Invoke-Sqlcmd -ServerInstance $server -Database $t -query $database_roles_query
   $user_file = "$file_location\groups\$t.sql"

   Write-Output "use [$t]"|Tee-Object -FilePath $user_file
   
    $db_name = $dbrole|select-object PrincipalName -ExpandProperty PrincipalName -unique
    
    
   #iterate through all the groups in the database 
    foreach ($s in $db_name) {
       $s1 = $s|out-string
       Write-Output ""|Tee-Object -FilePath $user_file -append
       Write-Output "Create Role $s1"|Tee-Object -FilePath $user_file -append
       
       $group_details = $dbrole|select state_desc,permission_Name,ObjectName,PrincipalName|where {$_.PrincipalName -eq $s}#|Format-Table -HideTableHeaders
        foreach ($w in $group_details) {
           #Write-Output $w
           
           $state = $w|select state_desc -ExpandProperty state_desc
           $permission = $w|select permission_Name -ExpandProperty permission_Name
           $object = $w|select ObjectName -ExpandProperty ObjectName
           $PrincipalName = $w| select PrincipalName -ExpandProperty PrincipalName

            Write-Output ""|Tee-Object -FilePath $user_file -append
            Write-Output "$state $permission on $object to $PrincipalName"|Tee-Object $user_file -append 
                         
                                        }


                                            }



                    }

}


function obj_permissions($db,$user,$server,$output_file){
$object_permission = "SELECT
  (
    dp.state_desc + ' ' +
    dp.permission_name collate latin1_general_cs_as + 
    ' ON ' + '[' + s.name + ']' + '.' + '[' + o.name + ']' +
    ' TO ' + '[' + dpr.name + ']'
  ) AS 'command'
FROM sys.database_permissions AS dp
  INNER JOIN sys.objects AS o ON dp.major_id=o.object_id
  INNER JOIN sys.schemas AS s ON o.schema_id = s.schema_id
  INNER JOIN sys.database_principals AS dpr ON dp.grantee_principal_id=dpr.principal_id
WHERE 1=1
 and dpr.name = '$user' 
ORDER BY dpr.name"



$perm =  Invoke-Sqlcmd -ServerInstance $server -Database $db -Query $object_permission

 Write-Output $perm.command | Tee-Object -FilePath $output_file -append 
 



}


  


  function get_users($server,$output_file) {
    
        
        
      
      
   $db = Invoke-Sqlcmd -ServerInstance $server -query $system_databases
    Write-Output ""|Tee-Object -FilePath $output_file -append 
    Write-Output "-- Creating users for login"| Tee-Object -FilePath $output_file -append 
    Write-Output ""|Tee-Object -FilePath $output_file -append 
foreach ($d in $db) {
  $d = $d|select name -ExpandProperty name
  $user_group_list = Invoke-Sqlcmd -ServerInstance $server -Database $d -query $create_user
  Write-Output $user_group_list
  #write-output $log
  $user_login =   $user_group_list|select-object user, role |where-object{$_.user -eq $log}#|out-string #|Format-Table -HideTableHeaders
  write-output $user_login
  Write-Output "if ((select count(*) from sys.databases where name = '$d') = 1) 
begin set @sql = 'use [$d];" |Tee-Object -FilePath $output_file -append 
    #Write-Output "go;" |Tee-Object -FilePath $output_file -append 
   $user_created = "n"
  foreach( $e in $user_login) {
  Write-Output "ROLE: $e.user\$e.role"
  $user = $e|select user -ExpandProperty user
  $role = $e|select role -ExpandProperty role
 if ($user_created -eq "n") {  
   if ($azure_AD -eq "n") {
    
    Write-Output " if ((select count(*) from sys.database_principals where name = ''$user'') = 0)"|Tee-Object -FilePath $output_file -append
    Write-Output "begin"|Tee-Object -FilePath $output_file -append 
    Write-Output "create user [$user] for login [$user]"|Tee-Object -FilePath $output_file -append 
    Write-Output "end"|Tee-Object -FilePath $output_file -append
    Write-Output "else"|Tee-Object -FilePath $output_file -append
    Write-Output "begin"|Tee-Object -FilePath $output_file -append 
    Write-Output "Alter User [$user] With Login = [$user]"|Tee-Object -FilePath $output_file -append
    Write-Output "end"|Tee-Object -FilePath $output_file -append
    $user_created = "y"
    }
    else {
      $name = $e.name.Split('\')[1]
       Write-Output " if ((select (count*) from sys.database_principals where name = ''$user'') = 0)"|Tee-Object -FilePath $output_file -append
    Write-Output "begin"|Tee-Object -FilePath $output_file -append 
    Write-Output "create user [$user] for login [$user]"|Tee-Object -FilePath $output_file -append 
    Write-Output "end"|Tee-Object -FilePath $output_file -append
    Write-Output "else"|Tee-Object -FilePath $output_file -append
    Write-Output "begin"|Tee-Object -FilePath $output_file -append 
    Write-Output "Alter User [$user] With Login = [$user]"|Tee-Object -FilePath $output_file -append
    Write-Output "end"|Tee-Object -FilePath $output_file -append
    $user_created = "y"
        }
 }
        if ($azure_AD -eq "n") {
        Write-Output "Exec sp_addrolemember ''$role'',''$user''"|Tee-Object -FilePath $output_file -append
        }
        else {
        $name = $e.name.Split('\')[1]
        Write-Output "Exec sp_addrolemember ''$role'',''$user''"|Tee-Object -FilePath $output_file -append
        }
    #set permissions 



                               }
obj_permissions $d $user $server $output_file

Write-Output "' exec (@sql) end"|Tee-Object -FilePath $output_file -append



  }

  }

  

  function get_logins($server) {

  $login_list = Invoke-Sqlcmd -serverinstance $server -query $login_query
     
  foreach ($log in $login_list) {
    ##create login script for each login
    $log1 =$log
    $log = $log|select name -ExpandProperty name
    $sqllogin = $log1|select type_desc -ExpandProperty type_desc
    $default = $log1|select dbname -ExpandProperty dbname
    $passwordhash = $log1|select password_hash -ExpandProperty password_hash
    $ispolicy = $log1|select is_policy_checked -ExpandProperty is_policy_checked
    $ispolicy = if($ispolicy -eq $True) {"ON"} else {"OFF"}
    $isexpiration = $log1| select is_expiration_checked -ExpandProperty is_expiration_checked
    $isexpiration = if($isexpiration -eq $TRUE) {"ON"} else {"OFF"}
    $filename = if ($log.Contains('\')) {
        $log.Split('\')[1]}
    else {$log} 
    $output_file = "$file_location\" + $filename + ".sql"
    
    #create the create login command for current known varients 
    Write-Output "-- Login script for $log" | Tee-Object -FilePath $output_file 
    write-output "
    Declare @sql varchar(4000)
    use master;
                  " | out-file $output_file -append
    if ($azure_AD -eq "n") {
        if ($sqllogin -eq "SQL_LOGIN") {
                Write-Output "if( (select count(*) from sys.syslogins where name = '$log') = 0)"|Tee-Object -FilePath $output_file -append 
                Write-Output "begin"| out-file $output_file -append
                Write-Output "Create LOGIN [$log] with password = N'$passwordhash', DEFAULT_DATABASE=[$default], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=$isexpiration, CHECK_POLICY=$ispolicy"|Tee-Object -FilePath $output_file -append 
                Write-Output "end"| Tee-Object -FilePath $output_file -append 

        } 
        else {
        Write-Output "if( (select count(*) from sys.syslogins where name = '$log') = 0)"|Tee-Object -FilePath $output_file -append 
        Write-Output "begin"| out-file $output_file -append
        
        Write-Output "Create Login [$log] FROM WINDOWS WITH DEFAULT_DATABASE=[$default], DEFAULT_LANGUAGE=[us_english]"|Tee-Object -FilePath $output_file -append 
        Write-Output "end"| Tee-Object -FilePath $output_file -append 
        }
                            }
    else {
        if ($sqllogin -eq "SQL_LOGIN") {
                Write-Output "if( (select count(*) from sys.syslogins where name = '$log') = 0)"|Tee-Object -FilePath $output_file -append 
                Write-Output "begin"| out-file $output_file -append
                Write-Output "Create LOGIN [$log] with password = N'$passwordhash', DEFAULT_DATABASE=[$default], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=$isexpiration, CHECK_POLICY=$ispolicy"
                Write-Output "end"| Tee-Object -FilePath $output_file -append 

        } 
        else {
        if ($log.Contains('\')) {
        $log = $log.Split('\')[1]}
         else {$log} 
        Write-Output "if( (select count(*) from sys.syslogins where name = '$log') = 0)"|Tee-Object -FilePath $output_file -append 
        Write-Output "begin"| Tee-Object -FilePath $output_file -append 
        Write-Output "Create Login [$log] FROM EXTERNAL PROVIDER WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]"|Tee-Object -FilePath $output_file -append 
       Write-Output "end"| Tee-Object -FilePath $output_file -append 
        }
        }
   $sysadmin = $log1| select sysadmin -ExpandProperty sysadmin
   $securityadmin= $log1| select securityadmin -ExpandProperty securityadmin
   $serveradmin = $log1| select serveradmin -ExpandProperty serveradmin
   $setupadmin = $log1| select setupadmin -ExpandProperty setupadmin
   $processadmin = $log1| select processadmin -ExpandProperty processadmin
   $diskadmin = $log1| select diskadmin -ExpandProperty diskadmin
   $dbcreator = $log1| select dbcreator -ExpandProperty dbcreator
   $bulkadmin = $log1| select bulkadmin -ExpandProperty bulkadmin

   if( $sysadmin -eq '1') {
    write-output ""| Tee-Object -FilePath $output_file -append 
    write-output "exec sp_addsrvrolemember '$log','sysadmin'"| Tee-Object -FilePath $output_file -append 
   }
   if( $securityadmin -eq '1') {
    write-output ""| Tee-Object -FilePath $output_file -append 
    write-output "exec sp_addsrvrolemember '$log','securityadmin'"| Tee-Object -FilePath $output_file -append 
   }
   if( $serveradmin -eq '1') {
    write-output ""| Tee-Object -FilePath $output_file -append 
    write-output "exec sp_addsrvrolemember '$log','serveradmin'"| Tee-Object -FilePath $output_file -append 
   }
   if( $setupadmin -eq '1') {
    write-output ""| Tee-Object -FilePath $output_file -append 
    write-output "exec sp_addsrvrolemember '$log','setupadmin'"| Tee-Object -FilePath $output_file -append 
   }
   if( $processadmin -eq '1') {
    write-output ""| Tee-Object -FilePath $output_file -append 
    write-output "exec sp_addsrvrolemember '$log','processadmin'"| Tee-Object -FilePath $output_file -append 
   }
   if( $diskadmin -eq '1') {
    write-output ""| Tee-Object -FilePath $output_file -append 
    write-output "exec sp_addsrvrolemember '$log','diskadmin'"| Tee-Object -FilePath $output_file -append 
   }
    if( $dbcreator -eq '1') {
    write-output ""| Tee-Object -FilePath $output_file -append 
    write-output "exec sp_addsrvrolemember '$log','dbcreator'"| Tee-Object -FilePath $output_file -append 
   }
   if( $bulkadmin -eq '1') {
    write-output ""| Tee-Object -FilePath $output_file -append 
    write-output "exec sp_addsrvrolemember '$log','bulkadmin'"| Tee-Object -FilePath $output_file -append 
   }

    #call function to create the users 
   # write-output "Go ;"| Tee-Object -FilePath $output_file -append 
    $server= $server.Trim()
    
    get_users -server $server.ToString() -output_file $output_file.ToString()

  }




  }

  ##list queries to be used in script 
  $database_roles_query = "SELECT DB_NAME() AS 'DBName'
      ,p.[name] AS 'PrincipalName'
      ,p.[type_desc] AS 'PrincipalType'
      ,p2.[name] AS 'GrantedBy'
      ,dbp.[permission_name]
      ,dbp.[state_desc]
      ,so.[Name] AS 'ObjectName'
      ,so.[type_desc] AS 'ObjectType'
  FROM [sys].[database_permissions] dbp LEFT JOIN [sys].[objects] so
    ON dbp.[major_id] = so.[object_id] LEFT JOIN [sys].[database_principals] p
    ON dbp.[grantee_principal_id] = p.[principal_id] LEFT JOIN [sys].[database_principals] p2
    ON dbp.[grantor_principal_id] = p2.[principal_id]
    where p.[type_desc] = 'DATABASE_ROLE' and p.[name] not in ('public')"
  
  $login_query = "select slog.name,dbname,sysadmin,securityadmin,serveradmin,setupadmin,processadmin,diskadmin,dbcreator,bulkadmin,ilog.type_desc,master.dbo.fn_varbintohexstr(ilog.password_hash) as 'password_hash',is_policy_checked,is_expiration_checked from sys.syslogins slog
left outer join (select name,type_desc,password_hash,is_policy_checked,is_expiration_checked from master.sys.sql_logins) ilog on slog.name = ilog.name"

$system_databases = 'select name from sys.databases'

  $create_user = "SELECT  DBUser.NAME 'user',DBRole.NAME  'role'
FROM sys.database_principals DBUser
left outer JOIN sys.database_role_members DBM ON DBM.member_principal_id = DBUser.principal_id
left outer JOIN sys.database_principals DBRole ON DBRole.principal_id = DBM.role_principal_id
WHERE  DBUser.Type IN (
		'U'
		,'S'
		)
	AND  DBUser.NAME NOT IN (
		'dbo'
		,'guest'
		,'sys'
		,'INFORMATION_SCHEMA'
		) and DBRole.name is not null 
"

  ##find the script parameters
  $server_to_script  = 'PON-WPSQ22-DB01\IN01,54596' 
  #Read-Host "Which Server do you want to script from: "
  $file_location =  'C:\Users\MOJONES\Documents\PROJECTS\DEMATIC MIGRATION\LOGIN'
  ##Read-Host "Where do you wish to create the login scripts: "
  $azure_AD = 'n' #Read-host "Is the instance you are restoring these logins to using Azure AD (y/n): "
 
  #run each part of the script 
  #get_usergroups($server_to_script)
  get_logins($server_to_script)
  
