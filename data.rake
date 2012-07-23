require 'nakamura/full_group_creator'
require 'nakamura/contacts'
require 'nakamura/message'
include SlingUsers
include SlingContacts
include SlingMessage

@um = FullGroupCreator.new(@sling)
@cm = ContactManager.new(@sling)
@mm = MessageManager.new(@sling)

#@sling.log.level = Logger::DEBUG

namespace :data do
  def get_count_offset
    count = (ENV['count'] || @num_users_groups).to_i
    offset = (ENV['offset'] || 0).to_i
    return count, offset
  end

  desc "Create initial content (users, connections, messages)"
  task :setup => ['data:users:create', 'data:connections:make', 'data:messages:send', 'data:groups:create']

  namespace :connections do

    def connect(u1, u2)
      user1 = User.new("user#{u1}", "test")
      user2 = User.new("user#{u2}", "test")
      @logger.info "Requesting connection between User #{u1} and User #{u2}"
      @sling.switch_user(user1)
      @logger.info @cm.invite_contact(user2.name, "Classmate")

      @logger.info "Accepting connection between User #{u1} and User #{u2}"
      @sling.switch_user(user2)
      @cm.accept_contact(user1.name)
      @sling.switch_user(User.admin_user)
    end

    desc "Make connections between each user and the next sequential user id"
    task :make do
      count, offset = get_count_offset
      count.times do |i|
        i += offset + 1
        n = i % count + 1
        connect(i, n) 
      end
    end

    desc "Create tons of connections for each user"
    task :maketons do
      count, offset = get_count_offset
      count.times do |i|
        i += offset + 1
        (count-1).times do |j|
          j += offset + 1
          unless i == j
            connect(i, j)
          end
        end
      end
    end
  end

  # ===========================================
  # = Creating users and groups =
  # ===========================================
  namespace :groups do
    desc "Add a lot of users as members to a group"
    task :addallusers do
      if (!(ENV["group"])) then
        @logger.info "Usage: rake data:groups:addallusers group=groupid-role"
      else
        group = Group.new(ENV["group"])
        count, offset = get_count_offset
        count.times do |i|
          i += offset + 1
          @logger.info "joining user#{i} to #{group.name}"
          @logger.info group.add_member(@sling, "user#{i}", "user") 
        end
      end
    end
    
    desc "Create groups (default count = #{@num_users_groups}; Each is created by the user with the matching id"
    task :create do
      count, offset = get_count_offset
      count.times do |i|
        i += offset + 1
        @logger.info "Creating Group #{i}"
        user = User.new("user#{i}", "test")
        @logger.info @um.create_full_group(user, "group#{i}", "Group #{i}", "Group #{i} description")
      end
    end
  end

  namespace :messages do

    def sendmessage(u1, u2, subject="Test message", body="Test message body", internalOnly=false)
      user1 = User.new("#{u1}", "test")
      @logger.info "Sending internal message: #{u1} => #{u2}"
      @sling.switch_user(user1)
      content = {
        "sakai:subject" => subject,
        "sakai:body" => body
      }
      res = @mm.create("#{u2}", "internal", "outbox", content) 
      message = JSON.parse(res.body)
      @mm.send(message["id"], "#{u1}")

      unless internalOnly
        @logger.info "Sending smtp message: #{u1} => #{u2}"
        res = @mm.create("#{u2}", "smtp", "pending", content) 
        message = JSON.parse(res.body)
        @mm.send(message["id"], "#{u1}")
      end

      @sling.switch_user(User.admin_user)
    end

    desc "Send messages between users"
    task :send do
      count, offset = get_count_offset
      count.times do |i|
        i += offset + 1
        nextuser = i % count + 1
 
        sendmessage("user#{i}", "user#{nextuser}", "test #{i} => #{nextuser}", "test body #{i} => #{nextuser}") 
          
        sendmessage("user#{nextuser}", "user#{i}", "test #{nextuser} => #{i}", "test body #{nextuser} => #{i}")

      end
    end
  
    desc "Send lots of messages to the specified user, from the specified user"
    task :sendlots do
      if (!(ENV["to"] && ENV["from"] && ENV["num"])) then
        @logger.info "Usage: rake sendlotsofmessages to=user1 from=user2 num=60"
      else
        to = ENV["to"]
        from = ENV["from"]
        num = ENV["num"].to_i
        @logger.info "Sending #{num} messages from #{from} to #{to}"
        num.times do |i|
          sendmessage("#{to}", "#{from}", "Message #{i} #{from} => #{to}", "Body of Message #{i} #{from} => #{to}", true)
        end
      end
    end
  end

  namespace :users do
    desc "Create users. Defaults to #{@num_users_groups}"
    task :create do
      count, offset = get_count_offset
      count.times do |i|
        i += offset + 1
        @logger.info "Creating User #{i}"
        user = User.new("user#{i}")
        user.firstName = "User"
        user.lastName = "#{i}"
        user.password = "test"
        @logger.info @um.create_user_object(user)
      end
    end
  end
end
