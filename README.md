# Functionality #

This application accesses the user's inbox and then submits the present emails as request items. the application then removes those emails from the inbox and places them in a folder of the user's choosing.

# Implementation #

Navigate to https://rcedev.kineticdata.com/kinetic-task/app/trees and find the task tree you wish to connect to this application. Take the values of the Source, Group and Tree columns and inject them into the following variables below:

*@sourceRoot* = Source
*@sourceGroup* = Group
*@sourceTree* = Tree

after setting up a service account key for the gmail api, Download the P12 file created in https://console.developers.google.com/apis/credentials then click on 'manage service accounts',

*service_account_email* = email address (or Client ID of the service account used to access the API)
*p12_file_name* = name of the imported p12 file
*@userId* = personal email address used to gain API access
*enable_debug_logging* = 'Yes'

# Defines application variable paths
*@processedFolder* = 'Label_1'
*key_location* = the path to the p12 file ending with *p12_file_name* as the destination
