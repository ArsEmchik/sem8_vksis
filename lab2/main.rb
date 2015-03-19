require 'socket'
require 'colorize'

class Node
  OWN_PORT = 2000.freeze # use this constant if you not on localhost
  ACTIVE, BUSY = 1.freeze
  NOT_ACTIVE, NOT_BUSY = 0.freeze

  #######################################################
  # format for marker
  # 1) status: [BUSY, NOT_BUSY]
  # 2) monitor_status: [ACTIVE, NOT_ACTIVE]
  # 3) priority: [0..7]
  # 4) reserve_priority: [0..7]
  # 5) node_to
  # 6) pc_to
  # 7) data
  # 8) node_from
  #######################################################

  def initialize
    puts 'Enter NODE NUMBER to connect to: '
    @node_number = input_validator { |data| data >= 1 && data <= 10 }

    @is_monitor = (@node_number == 1)

    puts 'Enter your node PRIORITY: '
    @node_priority = input_validator { |data| data >= 0 && data <= 6 }

    puts 'Enter OWN PORT: '
    @port = input_validator { |data| data >= 3000 && data <= 3100 }

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

    if @is_monitor
      @prev_node.puts(generate_msg)
      puts "First node: send msg #{generate_msg}".green
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
      p 'Im here'
      prev_node_message = @next_node.gets.chomp
      next if prev_node_message.empty?

      prev_node_message = marker_logic(prev_node_message) if @node_number == 1

      state, monitor_status, priority, reserve_priority, n_to, pc_to, data, n_from = parse_marker(prev_node_message)
      p [state, monitor_status, priority, reserve_priority, n_to, pc_to, data, n_from]
      puts "Get marker from #{n_from} node (to #{n_to} node). P/Rp: #{priority}/#{reserve_priority} ".yellow + "Data:  #{data}".green

      if state == BUSY
        reserve_priority = @node_priority if @node_priority > reserve_priority && !@pc_message_queue.empty?
        @prev_node.puts(generate_msg(state, monitor_status, priority, reserve_priority, n_to, pc_to, data))
        next
      end

      if @node_priority >= priority
        priority = @node_priority

        if n_to == @node_number
          @pc_queue[pc_to - 1].puts data if @pc_queue[pc_to - 1]
          reserve_priority = 0 # -

          if @pc_message_queue.empty?
            @prev_node.puts(generate_msg(NOT_BUSY, monitor_status, priority, reserve_priority, n_to, pc_to, data))
          else
            monitor_status = 0
            hole_data = @pc_message_queue.first
            n_to, pc_to, data = hole_data.split(":")
            @prev_node.puts(generate_msg(BUSY, monitor_status, priority, reserve_priority, n_to, pc_to, data))
          end
        end
      else
        reserve_priority = @node_priority if @node_priority > reserve_priority && !@pc_message_queue.empty?
        @pc_queue[pc_to - 1].puts data if n_to == @node_number && @pc_queue[pc_to - 1]

        if n_from == @node_number
          puts 'Package is not delivered!'.red
          @pc_queue[pc_to - 1].puts 'Package is not delivered!' if @pc_queue[pc_to - 1]
        end

        @prev_node.puts(generate_msg(NOT_BUSY, monitor_status, priority, reserve_priority, n_to, pc_to, data))
      end
    end
  end

  # only for first node logic
  def marker_logic(prev_node_message)
    state, monitor_status, priority, reserve_priority, n_to, pc_to, data, n_from = parse_marker(prev_node_message)
    priority = reserve_priority if monitor_status == ACTIVE
    monitor_status = ACTIVE
    generate_msg(state, monitor_status, priority, reserve_priority, n_to, pc_to, data, n_from)
  end

  def generate_msg(state = BUSY, monitor_status = ACTIVE, priority = 7,
                   reserve_priority = 0, n_to = 0, pc_to = 0, data = 'no_data', n_from = @node_number)

    "#{state}:#{monitor_status}:#{priority}:#{reserve_priority}:#{n_to}:#{pc_to}:#{data}:#{n_from}"
  end

  def get_address(str)
    host, port = str.split(":")
    return host, port.to_i
  end

  def parse_marker(message)
    state, monitor_status, priority, reserve_priority, n_to, pc_to, data, n_from = message.split(":")
    return state.to_i, monitor_status.to_i, priority.to_i, reserve_priority.to_i, n_to.to_i, pc_to.to_i, data, n_from.to_i
  end

  def input_validator
    while TRUE
      data = gets.chomp.to_i
      yield(data) ? break : puts('Format error! Enter once more: ')
    end
    data
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
