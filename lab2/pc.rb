require 'socket'
require 'colorize'

class PC
  def initialize
    puts 'Enter HOST to connect to: '
    host = gets.chomp
    puts 'Enter PORT to connect to: '
    port = gets.chomp.to_i

    @node = TCPSocket.new(host, port)
    Thread.new { enter_msg }
    listen_node
  end

  private

  def listen_node
    while sleep(1)
      data = @node.gets.chomp
      next if data.empty?

      puts 'RECEIVED: '.green + data
    end
  end

  def enter_msg
    while TRUE do
      puts '='*20 + "\n" + 'Enter the message please: '
      msg = gets.chomp

      if msg #chack valid here
        @node.puts(msg)
      else
        puts 'Error format! use 3:0:data please'.blue
      end
    end
  end
end

PC.new
