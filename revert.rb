#!/usr/bin/env ruby
require 'google/api_client'
require 'google/api_client/version'
require 'rubygems'
require 'rest_client'
require 'json'
require 'open-uri'

# Kinetic Task Tree Route
#Variables required to form a connection with the Kinetic Task Engine
@sourceRoot = 'Kinetic Task'
@sourceGroup = 'catalog > emailtask-tree'
@sourceTree = 'email_task-tree'

# Gmail Api Route Data
#Variables required to successfully connect to the Gmail API
service_account_email = '637058011697-d1esl5ifkslkmvsrthmv8fq2gogfpgpa@developer.gserviceaccount.com'
p12_file_name = 'Kinetic Task Sources-fd154b22eb39.p12'
@userId = 'test.user@kineticdata.com'
enable_debug_logging = 'Yes'

# Defines application variable paths
@processedFolder = 'Label_1'
key_location = p12_file_name

if !File.exist? key_location
  key_location = p12_file_name
  if !File.exist? key_location
    raise StandardError, "Invalid Info Value: The Info Value " + p12_file_name + " does not point to a p12 file in the resources directory nor does it point to a p12 file in the filesystem."
  end
end

key = nil
File.open(key_location, 'rb') do |io|
  key = Google::APIClient::KeyUtils.load_from_pkcs12(io.read, "notasecret")
end

# Initialize the API
@client = Google::APIClient.new({:authorization => :oauth_2})
@client.authorization = Signet::OAuth2::Client.new(
  :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
  :audience => 'https://accounts.google.com/o/oauth2/token',
  :scope => "https://www.googleapis.com/auth/gmail.modify",
  :issuer => service_account_email,
  :person => @userId,
  :signing_key => key)
@client.authorization.fetch_access_token!

puts "Google API Client fully configured" if @enable_debug_logging

@gmail_api = @client.discovered_api('gmail', 'v1')

# Sends the current Email to the 'processed' folder
def modifyMessage(messageId)
  resp = @client.execute!(
    api_method: @gmail_api.users.messages.modify,
    parameters: { userId: @userId, id: messageId },
    body_object: { addLabelIds: ['INBOX'], removeLabelIds: [@processedFolder]})
end

# Retrieves message details from the Gmail API
def getMessage(messageId)
  resp = @client.execute!(api_method: @gmail_api.users.messages.get,
    parameters: { userId: @userId, id: messageId })
  # Removes chat messages from the API results
  if resp.data.labelIds.include? 'CHAT' then
      return 'CHAT'
  end

  return resp
end

# Pulls back a list of the user's messages from the Gmail API
def requestList()
  results = @client.execute!(
    api_method: @gmail_api.users.messages.list,
    parameters: { userId: 'me', labelIds: @processedFolder },
    headers: {'Content-type' => 'application/json'}
  )

  # Checks for a processing error
  if (results.response.status != 200) then
    puts JSON.parse(results.response.body).inspect
    raise StandardError, JSON.parse(results.response.body)['error']['message']
  end

  # Checks if there are no messages found during the API call
  if results.data.messages.empty? then
    puts "No messages found"
    return <<-RESULTS
    <results/>
    RESULTS
  end

  # Takes each message from the list and retrieves that message's content
  results.data.messages.each do |message|
    parsedMessage = getMessage(message.id)
    if parsedMessage == "CHAT" then
      next
    end
    #calls funtions that move parsedMessage data
    modifyMessage(message.id)
  end
end

requestList()
