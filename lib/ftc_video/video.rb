# frozen_string_literal: true

module FtcVideo
  class Video
    attr_reader :event
    attr_reader :files

    def initialize(event)
      @event = event
      @files = []
    end

    def add_file(filename, start_time)
      files << VideoFile.new(self, filename, start_time)
    end

    def include?(time, duration)
      files.any? { |f| f.include?(time, duration) }
    end

    def video_file_at(time, duration = 0)
      files.find { |f| f.include?(time, duration) }
    end

    def extract_video(output_filename, time, duration, **options)
      video_file_at(time, duration)&.extract(output_filename, time, duration, **options)
    end

    def screenshot(output_filename, time)
      video_file_at(time)&.screenshot(output_filename, time)
    end

    def match_filename_prefix(match)
      "#{event.short_name}_#{match.short_identifier}_#{match.started.strftime('%Y%m%d_%H%M%S')}"
    end

    def match_video_filename(match)
      "#{match_filename_prefix(match)}_match.mkv"
    end

    def extract_match_video(match, before_start: 10, duration: 190, **options)
      filename = match_video_filename(match)
      filename if extract_video(filename, match.started - before_start, duration, **options)
    end
  end
end
