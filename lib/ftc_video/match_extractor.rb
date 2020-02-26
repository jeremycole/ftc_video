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
      produce_final_videos: false,
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
        opts.on('-f', '--[no-]produce-final-videos') { |o| options[:produce_final_videos] = o }
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

    def pretty_duration(seconds)
      result = String.new

      if seconds > 3600
        result << "#{seconds.to_i / 3600}h "
        seconds %= 3600
      end

      if seconds > 60
        result << "#{seconds.to_i / 60}m "
        seconds %= 60
      end

      result << format('%.1fs', seconds)

      result
    end

    def print_event_summary
      puts 'Event:'
      puts "  League  : #{event.league.name}" if event.league
      puts "  Name    : #{event.name}"
      puts "  Date    : #{event.start.strftime('%Y-%m-%d')}"
      puts

      puts 'Phases:'
      event.each_phase do |phase|
        puts '  %-20s:%3i matches' % [phase.name, phase.matches.count]
      end
      puts

      puts 'Teams:'
      event.each_team do |team|
        puts '  %5s %-40s %s' % [
          team.number,
          team.name || 'Unknown',
          team.location || 'Unknown',
        ]
      end
      puts

      puts 'Videos:'
      video.files.each do |video_file|
        puts '  %s, %s - %s, %s' % [
          File.basename(video_file.filename),
          video_file.start_time.strftime('%T'),
          video_file.end_time.strftime('%T'),
          pretty_duration(video_file.end_time - video_file.start_time)
        ]
      end
      puts
    end

    def extract_match(match)
      puts "#{match.long_name} starting at #{match.started}:"
      short_title = "#{match.short_description} at #{event.name} on #{match.started.strftime('%b %-d, %Y')}"
      puts "  Short Title (#{short_title.size} characters):\n#{short_title}"
      long_title = "#{match.long_description} at #{match.event.name} "
      puts "  Long Title (#{long_title.size} characters):\n#{long_title}"
      FtcEvent::ALLIANCES.each do |alliance|
        puts "#{alliance.capitalize} Alliance, #{match.result_for(alliance)}:"
        match.each_team(alliance) do |team|
          puts "  #{team.full_description}"
        end
      end

      if @options[:extract_videos]
        print '  Extracting match video... '

        match_video_filename = output_filename("#{video.match_filename_prefix(match)}_match.mkv")
        match_video_start_time = match.started - options[:seconds_before_match_start]
        match_video_duration =
          @options[:seconds_before_match_start] +
            @options[:seconds_match_length] +
            @options[:seconds_after_match_end]

        match_video_in_file = video.video_file_at(match_video_start_time, match_video_duration)
        match_video_offset = match_video_in_file.time_offset(match_video_start_time)

        match_video = match_video_in_file.movie.transcode(
          match_video_filename,
          {
            custom: [
              '-c:v', 'h264',
              '-profile:v', 'baseline',
              '-level', '3.0',
              '-b:v', '6M',
              '-c:a', 'aac',
              '-pix_fmt', 'yuv420p',
            ]
          },
          {
            input_options: {
              ss: match_video_offset.to_s,
              t: match_video_duration.to_s
            }
          }
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
        result_time = metadata['results'][match.short_identifier]
        if result_time
          print '  Extracting match score screenshot... '
          video.screenshot(score_screenshot_filename, result_time)
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
              {
                custom: [
                  '-f', 'lavfi',
                  '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
                  '-map', '0:v:0',
                  '-map', '1:a:0',
                  '-c:v', 'h264',
                  '-c:a', 'aac',
                  '-pix_fmt', 'yuv420p',
                  '-vframes', '300',
                  '-r', '30',
                ]
              },
              transcoder_options
            )

            if score_movie
              puts 'OK.'
            else
              puts 'failed.'
            end
          end
        end

        if score_movie && options[:produce_final_videos]
          print '  Making final video... '
          final_movie_filename = output_filename("#{video.match_filename_prefix(match)}_final.mkv")
          match_movie = FFMPEG::Movie.new(match_video_filename)
          final_movie = match_movie.transcode(final_movie_filename, {
            custom: [
              '-i', score_movie_filename,
              '-filter_complex', '[0:v:0][0:a:0][1:v:0][1:a:0]concat=n=2:v=1:a=1[outv][outa]',
              '-map', '[outv]',
              '-map', '[outa]',
              '-c:v', 'h264',
              '-profile:v', 'baseline',
              '-level', '3.0',
              '-b:v', '6M',
              '-c:a', 'aac',
              '-pix_fmt', 'yuv420p',
            ]
          })

          if final_movie
            puts 'OK.'
          else
            puts 'failed.'
          end
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
      event.each_phase do |phase|
        extract_matches_for_phase(phase)
      end
    end

    def run
      FFMPEG.logger = logger

      print_event_summary
      extract_matches
    end
  end
end

# rubocop:enable Metrics/ClassLength
