# frozen_string_literal: true

require 'streamio-ffmpeg'

module FtcVideo
  class VideoFile
    attr_reader :video
    attr_reader :filename
    attr_reader :movie
    attr_reader :start_time
    attr_reader :end_time

    def initialize(video, filename, start_time)
      @video = video
      @filename = filename

      @movie = FFMPEG::Movie.new(filename)

      @start_time = start_time
      @end_time = start_time + movie.duration
    end

    def include?(time, duration = 0)
      (time >= start_time) && ((time + duration) <= end_time)
    end

    def time_offset(time)
      (time - start_time).floor if include?(time)
    end

    def extract_at(output_filename, offset, duration, **options)
      transcode_options = {
        duration: duration
      }

      if options[:copy]
        transcode_options[:video_codec] = 'copy'
        transcode_options[:audio_codec] = 'copy'
      end

      movie.transcode(output_filename, transcode_options, { input_options: { ss: offset.to_s } })
    end

    def extract(output_filename, time, duration, **options)
      return unless include?(time, duration)

      extract_at(output_filename, time_offset(time), duration, **options)
    end

    def screenshot_at(output_filename, offset)
      transcoder_options = { input_options: { ss: offset.to_s } }
      movie.screenshot(output_filename, {}, transcoder_options)
    end

    def screenshot(output_filename, time)
      return unless include?(time)

      screenshot_at(output_filename, time_offset(time))
    end
  end
end
