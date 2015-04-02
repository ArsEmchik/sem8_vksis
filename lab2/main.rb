require 'socket'
require 'colorize'

class Node
  OWN_PORT = 2000 # use this constant if you not on localhost
  ACTIVE = 1.freeze
  BUSY = 1.freeze
  NOT_ACTIVE = 0.freeze
  NOT_BUSY = 0.freeze

  MAX_MISS = 3.freeze
  MAX_SEND = 3.freeze

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
    @node_priority = input_validator { |data| data >= 1 && data <= 6 }

    puts 'Enter OWN PORT: '
    @port = input_validator { |data| data >= 3000 && data <= 3100 }

    @pc_queue = []
    @pc_message_queue = []

    # 50.times do
    #   @pc_message_queue << ["1:1:from_#{@node_number}", "2:1:from_#{@node_number}"].sample
    # end

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
    count_miss = 0
    count_send = 0

    while sleep(1)
      prev_node_message = @next_node.gets.chomp
      next if prev_node_message.empty?

      prev_node_message = marker_logic(prev_node_message) if @node_number == 1

      state, monitor_status, priority, reserve_priority, n_to, pc_to, data, n_from = parse_marker(prev_node_message)

      puts 'Start node priority' + @node_priority.to_s
      puts "Marker from #{n_from} node to #{n_to} node. P/Rp: #{priority}/#{reserve_priority} ".yellow + "Data:  #{data}".green

      reserve_priority = @node_priority if @node_priority > reserve_priority && !@pc_message_queue.empty?

      if count_send >= MAX_SEND
        count_send = 0
        change_priority(:-)
      end

      if count_miss >= MAX_MISS
        count_miss = 0
        change_priority(:+)
      end

      if state == BUSY
        if n_to == @node_number
          monitor_status = ACTIVE and @pc_queue[pc_to - 1].puts data if @pc_queue[pc_to - 1]
        elsif n_from == @node_number
          monitor_status = ACTIVE
          puts 'Package is not delivered!'.red
        else
          count_miss += 1 if @node_priority < priority && !@pc_message_queue.empty? # --
          count_send = 0
          @prev_node.puts(generate_msg(BUSY, ACTIVE, priority, reserve_priority, n_to, pc_to, data, n_from))
          next
        end
      end

      if @node_priority >= priority
        if @pc_message_queue.empty?
          @prev_node.puts(generate_msg(NOT_BUSY, ACTIVE, priority, reserve_priority))
        else
          hole_data = @pc_message_queue.delete_at(0)
          n_to, pc_to, data = hole_data.split(":")
          @prev_node.puts(generate_msg(BUSY, NOT_ACTIVE, priority, reserve_priority, n_to, pc_to, data))
          count_send += 1
        end
      else
        count_miss += 1 unless @pc_message_queue.empty?
        @prev_node.puts(generate_msg(NOT_BUSY, monitor_status, priority, reserve_priority))
      end
    end
  end

  # lab 4
  def change_priority(operator)
    case
      when operator == :+
        if @node_priority < 6
          @node_priority += 1
          puts 'Change node priority! '.red + 'New is '.green + @node_priority.to_s.red
        else
          puts 'Node priority >= 6 !'.red
        end
      when operator == :-
        if @node_priority > 1
          @node_priority -= 1
          puts 'Change node priority! '.red + 'New is '.green + @node_priority.to_s.red
        else
          puts 'Node priority <= 1 !'.red
        end

      else
        puts 'Error'.red
    end
  end

  # only for first node logic
  def marker_logic(prev_node_message)
    state, monitor_status, priority, reserve_priority, n_to, pc_to, data, n_from = parse_marker(prev_node_message)

    if monitor_status == ACTIVE
      priority = reserve_priority
      reserve_priority = 0
    end

    generate_msg(state, monitor_status, priority, reserve_priority, n_to, pc_to, data, n_from)
  end

  def generate_msg(state = NOT_BUSY, monitor_status = ACTIVE, priority = 7,
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
