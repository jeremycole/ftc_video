# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength

module FtcVideo
  class MatchExtractor
    TIME_FROM_FILENAME = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/.freeze

    def self.extract_time_from_filename(filename)
      m = TIME_FROM_FILENAME.match(File.basename(filename).gsub(/[^\d]/, ''))
      return unless m

      Time.new(m[1], m[2], m[3], m[4], m[5], m[6], '-08:00')
    end

    DEFAULT_OPTIONS = {
      event_db_filename: nil,
      video_filenames: [],
      metadata_filename: nil,
      output_directory: '.',
      extract_videos: false,
      extract_result_images: false,
      extract_result_videos: false,
      copy: false,
      seconds_before_match_start: 10,
      seconds_match_length: 150,
      seconds_after_match_end: 30,
    }.freeze

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def self.parse_options
      options = DEFAULT_OPTIONS.dup

      OptionParser.new do |opts|
        opts.on('-h', '--help', 'Show this help.') { puts opts && puts && exit }
        opts.on('-d', '--event-db=DB', '') { |o| options[:event_db_filename] = o }
        opts.on('-v', '--video=FILE', '') { |o| options[:video_filenames] << o }
        opts.on('-m', '--metadata=FILE', '') { |o| options[:metadata_filename] = o }
        opts.on('-o', '--output-directory=DIR', '') { |o| options[:output_directory] = o }
        opts.on('-e', '--[no-]extract-videos') { |o| options[:extract_videos] = o }
        opts.on('-r', '--[no-]extract-result-images') { |o| options[:extract_result_images] = o }
        opts.on('-s', '--[no-]extract-result-videos') { |o| options[:extract_result_videos] = o }
        opts.on('--seconds-before-match-start=SECONDS') { |o| options[:seconds_before_match_start] = o.to_i }
        opts.on('--seconds-match-length=SECONDS') { |o| options[:seconds_match_length] = o.to_i }
        opts.on('--seconds-after-match-end=SECONDS') { |o| options[:seconds_after_match_end] = o.to_i }
        opts.on('-c', '--[no-]copy', '') { |o| options[:copy] = o }
      end.parse!

      options
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    def self.setup
      options = parse_options

      raise ArgumentError, 'Event database file not specified.' unless options[:event_db_filename]

      unless File.exist?(options[:event_db_filename])
        raise ArgumentError, "Event database file #{options[:event_db_filename]} does not exist."
      end

      FtcVideo::MatchExtractor.new(options)
    end

    attr_reader :options
    attr_reader :logger

    attr_reader :event
    attr_reader :video
    attr_reader :metadata

    def initialize(options)
      @options = options

      @logger = Logger.new(STDOUT, level: Logger::WARN)

      @event = FtcEvent::Event.new(options[:event_db_filename])
      @video = FtcVideo::Video.new(@event)

      options[:video_filenames].each do |filename|
        video.add_file(filename, FtcVideo::MatchExtractor.extract_time_from_filename(filename))
      end

      @metadata = YAML.load_file(options[:metadata_filename]) if options[:metadata_filename]
    end

    def output_filename(filename)
      File.join(Dir[options[:output_directory]], filename)
    end

    def print_event_summary
      puts 'Event:'
      puts "  League  : #{event.league.name}"
      puts "  Name    : #{event.name}"
      puts "  Date    : #{event.start.strftime('%Y-%m-%d')}"
      puts

      puts 'Phases:'
      event.each_phase do |phase|
        puts '  %-20s:%3i matches' % [phase.name, phase.matches.count]
      end
      puts

      puts 'Teams:'
      event.league.each_team do |team|
        puts '  %5s %-40s %s' % [
          team.number,
          team.name || 'Unknown',
          team.location || 'Unknown',
        ]
      end
      puts
    end

    def extract_match(match)
      puts "#{match.long_name} starting at #{match.started}:"
      long_title = "#{match.long_description} at #{match.event.name} "
      puts "  Long Title (#{long_title.size} characters):\n#{long_title}"
      short_title = "#{match.short_description} at #{match.event.name} on February 15, 2020"
      puts "  Short Title (#{short_title.size} characters):\n#{short_title}"
      FtcEvent::ALLIANCES.each do |alliance|
        puts "#{alliance.capitalize} Alliance, #{match.result_for(alliance)}:"
        match.each_team(alliance) do |team|
          puts "  #{team.full_description}"
        end
      end

      if @options[:extract_videos]
        print '  Extracting match video... '

        match_video_filename = output_filename("#{video.match_filename_prefix(match)}_match.mkv")
        match_video_duration =
          @options[:seconds_before_match_start] +
          @options[:seconds_match_length] +
          @options[:seconds_after_match_end]

        match_video = video.extract_video(
          match_video_filename,
          match.started - options[:seconds_before_match_start],
          match_video_duration,
          copy: @options[:copy]
        )
        if match_video
          puts 'OK.'
        else
          puts 'not present in video.'
        end
      end

      if (@options[:extract_result_images] || @options[:extract_result_videos]) &&
         metadata &&
         metadata['results'][match.short_identifier]
        score_screenshot_filename = output_filename("#{video.match_filename_prefix(match)}_score.png")
        time_at = metadata['results'][match.short_identifier]
        if time_at && time_at != 0
          print '  Extracting match score screenshot... '
          video.files.first.screenshot_at(score_screenshot_filename, time_at)
          score_screenshot = FFMPEG::Movie.new(score_screenshot_filename)

          if score_screenshot
            puts 'OK.'
          else
            puts 'failed.'
          end

          if @options[:extract_result_videos]
            print '  Making match score screenshot video... '
            score_movie_filename = output_filename("#{video.match_filename_prefix(match)}_score.mkv")
            transcoder_options = { input_options: { loop: '1' } }
            score_movie = score_screenshot.transcode(
              score_movie_filename,
              { vframes: 300, r: 30 },
              transcoder_options
            )
          end
        end

        if score_movie
          puts 'OK.'
        else
          puts 'failed.'
        end
      end
    end

    def extract_matches_for_phase(phase)
      puts "Starting #{phase.name}..."
      puts

      phase.each_match do |match|
        extract_match(match)
        puts
      end

      puts "Completed #{phase.name}."
      puts
    end

    def extract_matches
      puts "Starting #{phase.name}..."
      puts

      event.each_phase do |phase|
        extract_matches_for_phase(phase)
      end

      puts 'Done.'
      puts
    end

    def run
      FFMPEG.logger = logger

      print_event_summary

      event.each_phase do |phase|
        extract_matches_for_phase(phase)
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
