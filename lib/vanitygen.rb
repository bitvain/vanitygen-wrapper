require 'mkfifo'
require 'fileutils'
require 'open3'
require 'tempfile'

module Vanitygen
  autoload :VERSION, 'vanitygen/version'

  class << self
    NETWORKS = {
      bitcoin:  nil,
      testnet3: '-T',
      namecoin: '-N',
      litecoin: '-L',
    }

    def work_dir
      return @work_dir unless block_given?

      if @work_dir
        Dir.chdir @work_dir do
          yield
        end
      else
        yield
      end
    end

    def work_dir=(dir)
      @work_dir = dir
      if dir
        FileUtils.mkdir_p dir
      end
    end

    attr_accessor :executable
    def executable
      @executable ||= 'vanitygen'
    end

    def network
      @network ||= :bitcoin
    end

    def network=(network)
      network = network.to_sym
      raise "network #{network} not supported" unless NETWORKS.has_key?(network)
      @network = network
    end

    def valid?(pattern, options={})
      flags = flags_from(options, simulate: true, patterns: [pattern])

      work_dir do
        pid = Process.spawn(executable, *flags, out: '/dev/null', err: '/dev/null')
        pid, status = Process.wait2(pid)
        status == 0
      end
    end

    def difficulty(pattern, options={})
      flags = flags_from(options, simulate: true, patterns: [pattern])

      msg = ''
      work_dir do
        Open3.popen3(executable, *flags) do |stdin, stdout, stderr, wait_thr|
          stdin.close
          stdout.close
          while !stderr.eof?
            msg << stderr.read
          end
          stderr.close
          raise "vanitygen status (#{wait_thr.value}) err: #{msg}" if wait_thr.value != 0
        end
      end
      msg.split.last.to_i
    end

    def generate(pattern, options={})
      flags = flags_from(options, patterns: [pattern])

      msg = ''
      work_dir do
        Open3.popen3(executable, *flags) do |stdin, stdout, stderr, wait_thr|
          stdin.close
          while !stdout.eof?
            msg << stdout.read
          end
          stdout.close

          error = stderr.read
          stderr.close
          raise "vanitygen status (#{wait_thr.value}) err: #{error}" if wait_thr.value != 0
        end
      end

      parse(msg)[0]
    end

    def continuous(patterns, options={}, &block)
      raise LocalJumpError if block.nil?

      patterns_file = Tempfile.new('vanitygen-patterns-', work_dir)
      patterns.each do |pattern|
        patterns_file.puts pattern
      end
      patterns_file.flush

      tmp_pipe = File.join(work_dir || Dir.tmpdir, Time.now.strftime("vanitygen-pipe-%Y%m%d-#{rand(1000000)}"))
      File.mkfifo(tmp_pipe)

      flags = flags_from(options, continuous: true,
                                  patterns_file: patterns_file.path,
                                  output_file: tmp_pipe,
                                  patterns: patterns)

      pid_vanitygen = nil
      work_dir do
        # Unfortunately, vanitygen spams stdout with progress
        pid_vanitygen = Process.spawn(executable, *flags, out: '/dev/null', err: '/dev/null')

        while child_alive?(pid_vanitygen)
          File.open(tmp_pipe, 'r') do |file|
            while !file.eof? and (msg = file.read)
              parse(msg).each(&block)
            end
          end
        end
      end
    ensure
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

    def child_alive?(pid)
      # Very unix like
      # Unfortunately, not very ruby like :(
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end

    def flags_from(options, default)
      options = default.merge(options)

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
