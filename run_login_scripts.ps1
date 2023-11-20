﻿#########################################################################
#Author: M Jones                                                        #
#Date: 28/06/2023                                                       #
#Version: 1.0                                                           #
#Details: runs through a folder of sql scripts and apply them on desired#
#         sql instance                                                  #
# date     version   author                 details                     #
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# 28/06/2023 1.0      M Jones         Initial Script                    #
#########################################################################






$fileslocation = 'C:\Users\MOJONES\Documents\PROJECTS\DEMATIC MIGRATION\LOGIN'
$server = 'PON-WPSQ24-DB10\IN10,53282'

Get-ChildItem -path $fileslocation -Recurse|

ForEach-Object {

$_.Name
Invoke-Sqlcmd -server $server -inputfile $_.FullName



}