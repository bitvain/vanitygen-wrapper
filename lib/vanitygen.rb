require 'tempfile'

module Vanitygen
  autoload :VERSION, 'vanitygen/version'

  class << self
    NETWORKS = {
      bitcoin:  nil,
      testnet3: '-T',
    }

    def network
      @network ||= :bitcoin
    end

    def network=(network)
      network = network.to_sym
      raise "network #{network} not supported" unless NETWORKS.has_key?(network)
      @network = network
    end

    def type_flag
      NETWORKS[network]
    end

    def valid?(pattern)
      flags = [type_flag, '-n', pattern].compact
      pid = Process.spawn('vanitygen', *flags, out: '/dev/null', err: '/dev/null')
      pid, status = Process.wait2(pid)
      status == 0
    end

    def continuous(patterns, case_insensitive: false, &block)
      raise if block.nil?

      patterns_file = Tempfile.new('vanitygen-patterns')
      patterns.each do |pattern|
        patterns_file.puts pattern
      end
      patterns_file.flush

      tmp_pipe = "/tmp/vanitygen-pipe-#{rand(1000000)}"
      File.mkfifo(tmp_pipe)

      flags = [type_flag, '-k']
      flags << '-f' << patterns_file.path
      flags << '-o' << tmp_pipe
      flags << '-i' if case_insensitive
      flags.compact!

      thread = Thread.new do
        # FIXME: ignore EOF instead of reopening
        loop do
          File.open(tmp_pipe, 'r') do |file|
            while !file.eof? and (msg = file.read)
              parse(msg).each do |data|
                block.call(data)
              end
            end
          end
        end
      end

      pid_vanitygen = Process.spawn('vanitygen', *flags)
      Process.wait(pid_vanitygen)
    ensure
      thread.kill
      if pid_vanitygen
        begin
          Process.kill('TERM', pid_vanitygen)
          Process.detach(pid_vanitygen) # if no detach, vanitygen will zombify
        rescue Errno::ESRCH
          # vanitygen died by itself. Ignore and continue cleanup.
        end
      end

      File.delete tmp_pipe
      patterns_file.close
      patterns_file.unlink
    end

    def parse(msg)
      lines = msg.split("\n")
      lines.each_slice(3).map do |snippet|
        {
          pattern: snippet[0].split.last,
          address: snippet[1].split.last,
          private_key: snippet[2].split.last,
        }
      end
    end
  end
end
