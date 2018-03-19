class FtpLogController < ApplicationController
  def index
    url = params[:url]
    rip = request.ip

    if is_beijing?(rip)
      url = to_beijing_ftp(url) if hasfile?(url)
    end

    redirect_to url
  end

  def to_beijing_ftp(ftp)
    reg = /^.+@19\.9\.0\.162/
    target = "ftp://log:log@10.8.0.150"

    target += "/log" if /jmpzbrjcs/i.match(ftp)
    return ftp.gsub(reg, target)
  end

  def is_beijing?(ip)
    # return Regexp.new("^(10\\.1|10\\.2|10\\.5|10\\.6|10\\.7|10\\.8)").match(ip)
    /\A(10\\.1|10\\.2|10\\.5|10\\.6|10\\.7|10\\.8)/ === ip
  end

  def hasfile?(ftp)
    cmd = Api::ThirdpartyRelease::StudioCommand.new
    result = cmd.exec_command("curl -I #{ftp}")

    return result[3].read.blank?
  rescue => e
    return false
  end

  def ip_area(ip)
    citys = ['深圳', '东莞', '北京', '印度']
    config = ["^(18\\.|19\\.|192\\.168)",
              "^(10\\.15|15\\.5|16\\.6|16\\.9)",
              "^(10\\.1|10\\.2|10\\.5|10\\.6|10\\.7|10\\.8)",
              "^(10\\.20|10\\.21)"
    ]

    config.each_with_index { |key, idx|
      city = Regexp.new(key).match(ip) ? citys[idx] : city
    }

    city || citys.first
  end
end
