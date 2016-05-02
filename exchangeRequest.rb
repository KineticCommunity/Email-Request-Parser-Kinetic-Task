require 'net/imap'
require 'rest_client'

class TaskLink
  # Used to access Task
  attr_accessor :source_name, :source_group, :tree_name

  def initialize(args)
    @source_name = args[:source_name]
    @source_group = args[:source_group]
    @tree_name = args[:tree_name]
  end
end

@list = [
  TaskLink.new(
    source_name: 'Kinetic Task',
    source_group: 'catalog > emailtask-tree',
    tree_name: 'email_task-tree'
  )
]

class MailboxProcess
  # Used to access Task
  attr_accessor :address, :port, :encryption
  # Used to connect to the mailbox
  attr_accessor :user_email, :password, :getMailbox, :sendToMailbox
  def initialize(args)
    @address = args[:address]
    @port= args[:port]
    @encryption= args[:encryption]
    @user_email = args[:user_email]
    @password = args[:password]
    @getMailbox = args[:getMailbox]
    @sendToMailbox = args[:sendToMailbox]
  end
end

# to add an additional
emailServiceProviders = [
  MailboxProcess.new(
  address: "imap.gmail.com", port: 993, encryption: true, user_email: "test.user@kineticdata.com", password: "testAccount1", getMailbox: "DemoBox", sendToMailbox: "INBOX" ),
  MailboxProcess.new(
  address: "imap-mail.outlook.com", port: 993, encryption: true, user_email: "kineticdata@outlook.com", password: "testAccount1", getMailbox: "Read Mail", sendToMailbox: "Inbox"),
  MailboxProcess.new(
  address: "imap.mail.yahoo.com", port: 993, encryption: true, user_email: "kineticdata@yahoo.com", password: "testAccount1", getMailbox: "Read Mail", sendToMailbox: "Inbox")
]

class String
  def string_between_markers marker1, marker2
    self[/#{Regexp.escape(marker1)}(.*?)#{Regexp.escape(marker2)}/m, 1]
  end
end

while true
  emailServiceProviders.each do |esp|
    puts esp.address
    imap = Net::IMAP.new(esp.address, esp.port, esp.encryption)
    imap.login(esp.user_email, esp.password)
    imap.select(esp.getMailbox)
    msgs = imap.search(['ALL'])
    emailHeaders = Hash.new
    msgs.each do |id|
      imap.copy(id, esp.sendToMailbox)
      imap.store(id, "+FLAGS", [:Deleted])
    end
    imap.expunge
    imap.logout
    imap.disconnect
  end
  sleep 60
end
