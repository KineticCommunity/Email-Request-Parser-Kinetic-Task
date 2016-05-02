#!/usr/bin/env ruby
require 'google/api_client'
require 'google/api_client/version'
require 'rubygems'
require 'rest_client'
require 'json'
require 'open-uri'

class MailboxProcess
  # Used to access Task
  attr_accessor :source_name, :source_group, :tree_name
  # Used to connect to the mailbox
  attr_accessor :user_email, :service_account_email, :p12_file_name, :email_label

  def initialize(args)
    @source_name = args[:source_name]
    @source_group = args[:source_group]
    @tree_name = args[:tree_name]
    @user_email = args[:user_email]
    @service_account_email = args[:service_account_email]
    @p12_file_name = args[:p12_file_name]
    @email_label = args[:email_label]
  end
end

# to add an additional

@list = [
  MailboxProcess.new(
    source_name: 'Kinetic Task',
    source_group: 'catalog > emailtask-tree',
    tree_name: 'email_task-tree',
    service_account_email: '637058011697-d1esl5ifkslkmvsrthmv8fq2gogfpgpa@developer.gserviceaccount.com',
    p12_file_name: 'Kinetic Task Sources-fd154b22eb39.p12',
    user_email: 'test.user@kineticdata.com',
    email_label: 'Label_1')
]

@list.each do |mailbox|
  # Kinetic Task Tree Route
  # Variables required to form a connection with the Kinetic Task Engine
  @sourceRoot = mailbox.source_name
  @sourceGroup = mailbox.source_group
  @sourceTree = mailbox.tree_name

  # Gmail Api Route Data
  # Variables required to successfully connect to the Gmail API
  service_account_email = mailbox.service_account_email
  p12_file_name = mailbox.p12_file_name
  @userId = mailbox.user_email
  enable_debug_logging = 'Yes'

  # Defines application variable paths
  @processedFolder = mailbox.email_label
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
end
# Outputs the information taken from the Google API call

def handleMessage(parsedMessage)
  # authorization (basic base 64 encoded)
  response = RestClient.post(URI::encode('https://rcedev.kineticdata.com/kinetic-task/app/api/v1/run-tree/'+@sourceRoot+'/'+@sourceGroup+'/'+@sourceTree),
  parsedMessage.to_json, content_type: 'application/json')
  puts response
  puts "HM: #{parsedMessage.class} #{parsedMessage}"
end

# Sends the current Email to the 'processed' folder
def modifyMessage(messageId)
  resp = @client.execute!(
    api_method: @gmail_api.users.messages.modify,
    parameters: { userId: @userId, id: messageId },
    body_object: { addLabelIds: [@processedFolder], removeLabelIds: ['INBOX']})
end

# takes the results from the getMessage function and sets them in an object
def parseHeaders(resp)
  emailHeaders = Hash.new
  resp.data.payload.headers.each do |response|
  if response.name == "Subject"
    emailHeaders["Subject"] = response.value
  elsif response.name == "To"
    emailHeaders["To"] = response.value
  elsif response.name == "From"
    emailHeaders["From"] = response.value
  elsif response.name == "Cc"
    emailHeaders["Cc"] = response.value
  elsif response.name == "Bcc"
    emailHeaders["Bcc"] = response.value
  end
end
return emailHeaders
end

# Retrieves message details from the Gmail API
def getMessage(messageId)
  resp = @client.execute!(api_method: @gmail_api.users.messages.get,
    parameters: { userId: @userId, id: messageId })
  # Removes chat messages from the API results
  if resp.data.labelIds.include? 'CHAT' then
      return 'CHAT'
  end

  email = Hash.new
  email = parseHeaders(resp)
  if resp.data.payload.mimeType == "text/plain"
    email["Body"] = resp.data.payload.body.data.gsub('\\r', "\r").gsub('\\n', "\n")
  else
    parts = resp.data.payload.parts
    parts.each do |part|
      if part.mimeType == "text/plain"
        email["Body"] = part.body.data.gsub('\\r', "\r").gsub('\\n',"\n")
      end
    end
  end

  return email
end

# Pulls back a list of the user's messages from the Gmail API
def requestList()
  results = @client.execute!(
    api_method: @gmail_api.users.messages.list,
    parameters: { userId: 'me', labelIds: 'INBOX' },
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
    #calls funtions that manipulate parsedMessage data
    handleMessage(parsedMessage)
    modifyMessage(message.id)
  end

  return <<-RESULTS
  <results/>
  RESULTS
end

# preforms the requestList function, then sleeps for 60 seconds in an infinite loop
while true
  requestList()
  sleep 60
end
