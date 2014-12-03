# vanitygen-wrapper

Thin ruby wrapper around vanitygen executable. Sibling project of <https://github.com/bitvain/vanitygen-ruby>.

## Warning

Due to rampant use of pipes, signals, and subprocesses, this gem probably does
not work in JRuby or Windows.

This also cannot be effectively tested in CI due to depending on an external
executable.

Discretion is advised.

## Installation

Download and install <https://github.com/samr7/vanitygen>

Make sure `vanitygen` is available in your `$PATH`.

Add this line to your application's Gemfile:

```ruby
gem 'vanitygen-wrapper', require: 'vanitygen'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vanitygen-wrapper

## Usage

Verify pattern validity:

```ruby
>> Vanitygen.valid?('1AB')
=> true
>> Vanitygen.valid?('2AB')
=> false
```

Check pattern difficulty:

```ruby
>> Vanitygen.difficulty('1AB')
=> 1330
>> Vanitygen.difficulty('1AB', case_insensitive: true)
=> 654
```

Generate single addresses:

```ruby
>> Vanitygen.generate('1AB')
=> {:pattern=>"1AB", :address=>"1ABz3svEbWHyj5penc6LLX6xvDfzZcsZu9", :private_key=>"5KRtsDfuiMf549QU1X6mNcTuYxd2V4XsjQBD8pgUMEPFGFADMzb"}
```

Continuously generate addresses:

```ruby
>> Vanitygen.continuous('1AB') { |data| puts data }
{:pattern=>"1AB", :address=>"1ABsD3pMDJbmpQx941faFn5Tg7aeVccW9c", :private_key=>"5KAjmVJAoBgNNNtVqCWYofNH6N8erSBGd7omsLCzSWg9DHZJd15"}
{:pattern=>"1AB", :address=>"1ABzPupWHxiWRBhAPYmcxbBQoonE1CgF7u", :private_key=>"5KRB9rV78DdTp6RWD7K1mA7iNgRGTXDuA7aGvC4xJLPg4YLx5j2"}
{:pattern=>"1AB", :address=>"1ABc8fVqFW2SXBfmQh5B6u1cg9SEPF2xMP", :private_key=>"5JAVeQBXT2ZL5p6oLgK4QAiDVdC8J9ytLHT999TxzSwvHnkgu3T"}
[...]
```

## Contributing

1. Fork it ( https://github.com/bitvain/vanitygen-wrapper/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
