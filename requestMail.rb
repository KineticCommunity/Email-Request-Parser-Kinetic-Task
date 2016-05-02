require 'net/imap'
require 'rest_client'
require 'mail'
require 'base64'

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
        address: "imap.gmail.com", port: 993, encryption: true, user_email: "kinetic.testuser@gmail.com", password: "testAccount1", getMailbox: "INBOX", sendToMailbox: "DemoBox"
    ),
    MailboxProcess.new(
        address: "imap-mail.outlook.com", port: 993, encryption: true, user_email: "kineticdata@outlook.com", password: "testAccount1", getMailbox: "Inbox", sendToMailbox: "Read Mail"
    ),
    MailboxProcess.new(
        address: "imap.mail.yahoo.com", port: 993, encryption: true, user_email: "kineticdata@yahoo.com", password: "testAccount1", getMailbox: "Inbox", sendToMailbox: "Read Mail"
    )
]

class String
    def string_between_markers marker1, marker2
        self[/#{Regexp.escape(marker1)}(.*?)#{Regexp.escape(marker2)}/m, 1]
    end
end

def handleMessage(parsedMessage)
    @list.each do |task|
        # Kinetic Task Tree Route
        # Variables required to form a connection with the Kinetic Task Engine
        response = RestClient.post(URI::encode('https://rcedev.kineticdata.com/kinetic-task/app/api/v1/run-tree/'+task.source_name+'/'+task.source_group+'/'+task.tree_name), parsedMessage.to_json, content_type: 'application/json')
        puts "HM: #{parsedMessage.class}"
    end
end

while true
    emailServiceProviders.each do |esp|
        begin
            imap = Net::IMAP.new(esp.address, esp.port, esp.encryption)
            imap.login(esp.user_email, esp.password)
            imap.select(esp.getMailbox)
            msgs = imap.search(['ALL'])
            emailHeaders = Hash.new
            puts esp.user_email
            msgs.each do |id|
                body = imap.fetch(id, 'RFC822')[0].attr['RFC822']
                mail = Mail.new(body)
                data = imap.fetch(id, 'ENVELOPE')[0].attr['ENVELOPE']
                bodyArray = imap.fetch(id, "RFC822.TEXT")[0].attr['RFC822.TEXT'].split('Content-Type: text/html')
                if (esp.address === "imap.gmail.com")
                    emailHeaders["Body"] = bodyArray[0].string_between_markers("charset=UTF-8" ,"--").to_s.gsub("\r\n\r\n", " ").gsub("\r\n", " ")
                elsif (esp.address === "imap-mail.outlook.com")
                    emailHeaders["Body"] = bodyArray[0].string_between_markers("Content-Transfer-Encoding: quoted-printable" ,"--")
                elsif (esp.address === "imap.mail.yahoo.com")
                    emailHeaders["Body"] = bodyArray[0].string_between_markers("Content-Transfer-Encoding: 7bit" ,"--").to_s.gsub("\r\n\r\n", " ").gsub("\r\n", " ")
                end
                if mail.attachments != nil
                    mail.attachments.each do |attachment|
                        emailHeaders["Attachment"] = Base64.encode64(attachment.body.decoded)
                        # file.open(Base64.decode64(emailHeaders["Attachment"]), wb)
                    end
                end
                if data.cc != nil
                    data.cc.each do |copiedAddress|
                        emailHeaders["Cc"] = copiedAddress.mailbox + '@' + copiedAddress.host
                    end
                end
                if data.bcc != nil
                    data.bcc.each do |copiedAddress|
                        emailHeaders["Bcc"] = copiedAddress.mailbox + '@' + copiedAddress.host
                    end
                end
                data.from.each do |copiedAddress|
                    emailHeaders["From"] = copiedAddress.mailbox + '@' + copiedAddress.host
                end
                data.to.each do |copiedAddress|
                    emailHeaders["To"] = copiedAddress.mailbox + '@' + copiedAddress.host
                end
                if data.subject != nil
                    emailHeaders["Subject"] = data.subject
                end
                handleMessage(emailHeaders)
                imap.copy(id, esp.sendToMailbox)
                imap.store(id, "+FLAGS", [:Deleted])
            end
            imap.expunge
            imap.logout
            imap.disconnect
        rescue
            next
        end
    end
    sleep 60
end
