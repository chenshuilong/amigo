module Uploader

  # Dir[File.dirname(__FILE__) + "/uploaders/*.rb"].each { |file| require(file) }

  class AvatarUploader < CarrierWave::Uploader::Base

    include CarrierWave::RMagick

    def default_url
      "/uploads/avatar/default/avatar.jpg"
    end

    version :normal do
      process :resize_to_fill => [100, 100]
    end

    version :small do
      process :resize_to_fill => [50, 50]
    end

    version :large do
      process :resize_to_fill => [200, 200]
    end

    # crop image model.avatar_data
    process :crop_image

    def crop_image
      manipulate! do |img|
        data = model.crop_size
        x = data[:x].to_i
        y = data[:y].to_i
        w = data[:width].to_i
        h = data[:height].to_i
        img.crop!(x, y, w, h, true)
        img
      end
    end

    storage :file

    def store_dir
      "uploads/avatar/#{model.login}"
    end

    def extension_white_list
      %w(jpg jpeg png)
    end

  end


end
