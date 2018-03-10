#!/usr/bin/env ruby

class PretendEventHandler
  # this is the irc server getting the message, calling the on_msg hook, and trying to handle the block
  def servermsg(channel,msg)
    # would have a handle to @irc
    puts "PRIVMSG #{channel} :#{msg}"
  end

  # would be invoked and hunt for procs to execute 
  def on_msg(&block)
    @block_to_call = block
  end

  def gotmsg(nick, msg)
    @block_to_call.call(self, nick, msg)
  end
end

class PretendEventSubscriber
  # ideally, this passes a block that can understand things like "reply"

  def register_callback(handler)
    handler.on_msg do |irc, nick, msg|
      puts "FROM <#{nick}>: #{msg}"
      irc.servermsg(nick, "hello #{nick}")
    end
  end
end

handler = PretendEventHandler.new
app = PretendEventSubscriber.new
app.register_callback(handler)

# pretend the server raised a gotmsg event
handler.gotmsg("X-Jester", "hello friend")
