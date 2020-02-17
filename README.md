# FtcVideo - Tools for FTC Video

This is a Gem for, currently, extracting individual videos from a recording of a FIRST Tech Challenge competition, using the SQLite3 database file from the FTC scorekeeper application to find the match start times. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ftc_video'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ftc_video

## Usage

This would be a typical command to extract individual match videos:

```bash
$ ftc_video_match_extractor \
  -d ~/ftc_competitions/nnvfin/nnvfin.db \
  -v ~/ftc_competitions/nnvfin/resynced-20200215-105552.mkv \
  -m ~/ftc_competitions/nnvfin/nnvfin.yaml \
  -o ~/ftc_competitions/nnvfin/output_videos \
  --extract-videos \
  --extract-result-videos
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at [jeremycole/ftc_video](https://github.com/jeremycole/ftc_video).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
