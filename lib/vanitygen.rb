require 'mkfifo'
require 'open3'
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

    def valid?(pattern, options={})
      flags = flags_from({simulate: true,
                          patterns: [pattern]
                         }.merge(options))
      pid = Process.spawn('vanitygen', *flags, out: '/dev/null', err: '/dev/null')
      pid, status = Process.wait2(pid)
      status == 0
    end

    def difficulty(pattern, options={})
      flags = flags_from({simulate: true,
                          patterns: [pattern]
                         }.merge(options))
      msg = ''
      Open3.popen3('vanitygen', *flags) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        stdout.close
        while !stderr.eof?
          msg << stderr.read
        end
        stderr.close
        raise "vanitygen status (#{wait_thr.value}) err: #{msg}" if wait_thr.value != 0
      end
      msg.split.last.to_i
    end

    def generate(pattern, options={})
      flags = flags_from({patterns: [pattern]
                         }.merge(options))

      msg = ''
      Open3.popen3('vanitygen', *flags) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        while !stdout.eof?
          msg << stdout.read
        end
        stdout.close

        error = stderr.read
        stderr.close
        raise "vanitygen status (#{wait_thr.value}) err: #{error}" if wait_thr.value != 0
      end

      parse(msg)[0]
    end

    def continuous(patterns, options={}, &block)
      raise LocalJumpError if block.nil?

      patterns_file = Tempfile.new('vanitygen-patterns')
      patterns.each do |pattern|
        patterns_file.puts pattern
      end
      patterns_file.flush

      tmp_pipe = "/tmp/vanitygen-pipe-#{rand(1000000)}"
      File.mkfifo(tmp_pipe)

      flags = flags_from({continuous: true,
                          patterns_file: patterns_file.path,
                          output_file: tmp_pipe,
                          patterns: patterns,
                         }.merge(options))

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

      pid_vanitygen = Process.spawn('vanitygen', *flags, out: '/dev/null', err: '/dev/null')
      Process.wait(pid_vanitygen)
    ensure
      thread && thread.kill
      if pid_vanitygen
        begin
          Process.kill('TERM', pid_vanitygen)
          Process.detach(pid_vanitygen) # if no detach, vanitygen will zombify
        rescue Errno::ESRCH
          # vanitygen died by itself. Ignore and continue cleanup.
        end
      end

      tmp_pipe && File.exist?(tmp_pipe) && File.delete(tmp_pipe)
      if patterns_file
        patterns_file.close
        patterns_file.unlink
      end
    end

    private

    def flags_from(options)
      [].tap do |flags|
        patterns =
          if options[:patterns].nil?
            nil
          elsif options[:patterns].any? { |p| p.is_a?(Regexp) }
            if options[:patterns].all? { |p| p.is_a?(Regexp) }
              flags << '-r'
              options[:patterns].map(&:source)
            else
              raise TypeError
            end
          else
            options[:patterns].map(&:to_s)
          end

        flags << NETWORKS[network]               if NETWORKS[network]
        flags << '-n'                            if options[:simulate]
        flags << '-k'                            if options[:continuous]
        flags << '-i'                            if options[:case_insensitive]
        flags << '-f' << options[:patterns_file] if options[:patterns_file]
        flags << '-o' << options[:output_file]   if options[:output_file]
        flags.concat(patterns)                   if patterns && !options[:patterns_file]
      end
    end

    def parse(msg)
      lines = msg.split("\n").grep(/(Pattern|Address|Privkey)/)
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
