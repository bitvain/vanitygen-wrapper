require 'spec_helper'

require 'vanitygen'

require 'bitcoin'
require 'timeout'

describe Vanitygen do
  let(:pattern_string_a)  { '1A' }
  let(:pattern_string_b)  { '1B' }
  let(:pattern_string_ab) { '1AB' }
  let(:pattern_regex_ab)  { /[aA][bB]/ }
  let(:pattern_any)       { '1' }

  describe '.generate' do
    context 'string' do
      subject { Vanitygen.generate(pattern_string_a) }

      it 'has valid address' do
        assert{ Bitcoin.valid_address?(subject[:address]) }
      end

      it 'has address starting with pattern' do
        assert{ subject[:address].start_with?(pattern_string_a) }
      end

      it 'has correct private_key to unlock pattern' do
        bkey = Bitcoin::Key.from_base58(subject[:private_key])
        assert{ subject[:address] == bkey.addr }
      end
    end

    context 'regex' do
      subject { Vanitygen.generate(pattern_regex_ab) }

      it 'has valid address' do
        assert{ Bitcoin.valid_address?(subject[:address]) }
      end

      it 'has address matching pattern' do
        assert{ subject[:address] =~ pattern_regex_ab }
      end
    end
  end

  describe '.continuous' do
    it 'requires a block' do
      error = rescuing{ Vanitygen.continuous([pattern_any]) }
      assert{ error.is_a?(LocalJumpError) }
    end

    it 'requires same type' do
      noop = proc{}
      error = rescuing{ Vanitygen.continuous([pattern_regex_ab, pattern_string_a], &noop) }
      assert{ error.is_a?(TypeError) }
    end

    context 'threaded with capture block' do
      let(:captured) { [] }

      def capture(attr=nil)
        if attr.nil?
          proc { |data| captured << data }
        else
          proc { |data| captured << data[attr] }
        end
      end

      def continuous_with_timeout(patterns, options={}, &block)
        duration = options.delete(:timeout) || 0.1
        Timeout.timeout duration do
          Vanitygen.continuous(patterns, options, &block)
        end

        raise 'Expected timeout but did not happen'
      rescue Timeout::Error => e
        # expected
      end

      context 'base test' do
        before do
          continuous_with_timeout([pattern_any], &capture(:address))
        end

        it 'runs a lot' do
          assert{ captured.count > 10 }
        end

        it 'returns valid addresses' do
          assert{ captured.all? { |addr| Bitcoin.valid_address?(addr) } }
        end
      end

      context 'with string' do
        it 'starts with matching pattern' do
          continuous_with_timeout([pattern_string_a], &capture(:address))
          assert{ captured.size > 1 }
          assert{ captured.all? { |addr| addr.start_with?(pattern_string_a) } }
        end

        it 'matches with case insensitivity' do
          continuous_with_timeout([pattern_string_ab], case_insensitive: true, &capture(:address))
          prefixes = captured.map { |addr| addr[0..2] }
          assert{ prefixes.uniq.size > 1 }
        end

        it 'matches multiple patterns' do
          continuous_with_timeout([pattern_string_a, pattern_string_b], &capture(:address))
          assert{ captured.any? { |addr| addr.start_with?(pattern_string_a) } }
          assert{ captured.any? { |addr| addr.start_with?(pattern_string_b) } }
        end
      end

      context 'with regex' do
        it 'matches the regex' do
          continuous_with_timeout([pattern_regex_ab], &capture(:address))
          assert{ captured.size > 1 }
          assert{ captured.all? { |addr| addr =~ pattern_regex_ab } }
        end
      end
    end
  end

  describe '.difficulty' do
    it 'returns difficulty in Numeric' do
      assert{ Vanitygen.difficulty(pattern_string_a).is_a?(Numeric) }
    end
  end

  describe '.valid?' do
    it 'is true for starting with 1' do
      assert{ Vanitygen.valid?('1abc') }
    end

    it 'is false for starting with something else' do
      assert{ not Vanitygen.valid?('abc') }
    end

    it 'is false for really long strings' do
      assert{ not Vanitygen.valid?('1abcdefghijklmnopqrstuvwxyz') }
    end

    it 'is false for illegal characters' do
      assert{ not Vanitygen.valid?('10') }
      assert{ not Vanitygen.valid?('1O') }
      assert{ not Vanitygen.valid?('1I') }
      assert{ not Vanitygen.valid?('1l') }
    end
  end

  describe '.network' do
    it 'switches to :testnet3' do
      assert{ not Vanitygen.valid?('mm') }
      Vanitygen.network = :testnet3
      assert{ Vanitygen.valid?('mm') }
    end

    it 'switches to "testnet3"' do
      Vanitygen.network = 'testnet3'
      assert{ Vanitygen.valid?('mm') }
    end

    it 'stays on :bitcoin' do
      Vanitygen.network = :bitcoin
      assert{ Vanitygen.valid?('1a') }
    end

    it 'dies for missing network' do
      error = rescuing{ Vanitygen.network = :foobar }
      assert{ error.message =~ /not supported/ }
    end
  end
end
