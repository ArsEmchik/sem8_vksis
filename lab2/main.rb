require 'optparse'
require 'socket'
require 'colorize'

class Node
  OWN_PORT = 2000.freeze # use this constant if you not on localhost
  BUSY = 1.freeze
  NOT_BUSY = 0.freeze

  def initialize
    puts 'Enter NODE NUMBER to connect to: '
    @node_number = gets.chomp.to_i
    # puts 'Enter OWN IP to connect to: '
    # @ip = gets.chomp
    puts 'Enter OWN PORT: '
    @port = gets.chomp.to_i

    @pc_queue = []
    @pc_message_queue = []

    @flag = true

    Thread.new {
      server = TCPServer.new(@port)
      @prev_node, server_info = server.accept
      puts "#{@node_number} get connection with #{server_info}".red
      @flag = false
    }

    #get info from console
    puts 'Enter host:port to connect to: '
    @sent_host, @sent_port = get_address(gets.chomp)
    @next_node = TCPSocket.new(@sent_host, @sent_port)

    while @flag do
      sleep(1)
    end

    if @node_number == 1
      @prev_node.puts(generate_msg)
      puts "First node: send msg #{generate_msg}"
    end

    Thread.new { pc_listener }
    start
  end

  # test method for check node work
  def tmp_get_msg
    while TRUE do
      puts '='*20 + "\n" + 'Enter the message please: '
      @pc_message_queue << gets.chomp
    end
  end

  private

  # the base method for get/send msg form previous/next node
  def start
    while sleep(1)
      prev_node_message = @next_node.gets.chomp
      next if prev_node_message.empty?

      state, n_to, pc_to, data, n_from = parse_marker(prev_node_message)
      puts "Get marker from #{n_from} node (to #{n_to} node) ".yellow + "Data:  #{data}".green

      if state == NOT_BUSY
        if @pc_message_queue.empty?
          @prev_node.puts(generate_msg)
        else
          hole_data = @pc_message_queue.delete_at(0)
          n_to, pc_to, data = hole_data.split(":")
          @prev_node.puts(generate_msg(1, n_to, pc_to, data))
        end
      elsif n_to == @node_number
        # puts 'RECEIVED: '.green + data.to_s
        @pc_queue[pc_to - 1].puts data if @pc_queue[pc_to - 1]

        if @pc_message_queue.empty?
          @prev_node.puts(generate_msg)
        else
          hole_data = @pc_message_queue.first
          n_to, pc_to, data = hole_data.split(":")
          @prev_node.puts(generate_msg(1, n_to, pc_to, data))
        end
      elsif n_from == @node_number
        puts 'Package is not delivered!'.red
        @pc_queue[pc_to - 1].puts 'Package is not delivered!' if @pc_queue[pc_to - 1]
        @prev_node.puts(generate_msg)
      else
        @prev_node.puts(prev_node_message)
      end
    end
  end

  def generate_msg(state = 0, n_to = 0, pc_to = 0, data = 'no_data')
    "#{state}:#{n_to}:#{pc_to}:#{data}:#{@node_number}"
  end

  def get_address(str)
    host, port = str.split(":")
    return host, port.to_i
  end

  def parse_marker(message)
    state, n_to, pc_to, data, n_from = message.split(":")
    return state.to_i, n_to.to_i, pc_to.to_i, data, n_from.to_i
  end

  def pc_listener
    pc_server = TCPServer.new(2000 + @node_number)

    while TRUE
      Thread.start(pc_server.accept) do |client, info|
        puts 'Get connection form PC!'.red
        @pc_queue << client unless @pc_queue.include? info

        loop do
          message = client.gets.chomp
          next if message.empty?

          if message == 'exit'
            client.puts 'Bye bye!'
            client.close
          else
            @pc_message_queue << message
          end
        end
      end
    end
  end
end

Node.new
