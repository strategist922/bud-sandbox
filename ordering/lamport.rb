
require 'rubygems'
require 'bud'

class LamportMsg
  attr_accessor :clock
  attr_accessor :msg

  def initialize(clock, msg)
    @clock = clock
    @msg = msg
  end

  def to_s
    [@clock, @msg].inspect
  end

  def ==(another_msg)
    self.clock == another_msg.clock && self.msg == another_msg.msg
  end
end

module LamportInterface
  state do
    interface input, :to_stamp, [] => [:msg]
    interface output, :get_stamped, [:msg] => [:lamportmsg]
    interface input, :retrieve_msg, [:lamportmsg] => []
    interface output, :msg_return, [:lamportmsg] => [:msg]
  end
end

module LamportClockManager
  include LamportInterface

  state do
    table :localclock, [] => [:clock]

    table :action_buf, [] => [:actiontype, :msg, :queuetime]

    scratch :next_stamp, to_stamp.schema
    scratch :next_retrieve, retrieve_msg.schema
  end

  bootstrap do
    localclock <= [[0]]
  end

  bloom do

    temp :relativestamp <= to_stamp.each_with_index.to_a

    get_stamped <= (relativestamp * localclock).pairs do |m, c|
      [m[0][0], LamportMsg.new(m[1]+c.clock, m[0][0])]
    end

    msg_return <= retrieve_msg { |r| [r.lamportmsg, r.lamportmsg.msg] }

    localclock <- localclock
    localclock <+ localclock { |c|
      if retrieve_msg.length > 0
        [c.clock+
          [to_stamp.length+retrieve_msg.length,
            (retrieve_msg { |m| m.lamportmsg.clock }).max+1].max]
      else
        [c.clock+to_stamp.length+retrieve_msg.length]
      end
    }

=begin
    action_buf <= to_stamp { |s| ["S", s.msg, @budtime] }
    action_buf <= retrieve_msg { |r| ["R", r.lamportmsg, @budtime] }

    temp :nextaction <= action_buf.argmin([action_buf.actiontype, action_buf.msg,
                                            action_buf.queuetime],
                                   action_buf.queuetime)

    get_stamped <= (localclock * nextaction).pairs do |c, m|
      if m.actiontype == "S":
        localclock <- localclock
        localclock <+ localclock { |cv| [cv.clock + 1] }
        action_buf <- nextaction

        [m.msg, LamportMsg.new(c.clock, m.msg)]
      end
    end

    msg_return <= nextaction do |r|
      if r.actiontype == "R":
        localclock <- localclock
        localclock <+ localclock { |cv| [[cv.clock, r.msg.clock].max()+1] }

        action_buf <- nextaction

        [r.msg, r.msg.msg]
      end
    end
=end
  end
end


