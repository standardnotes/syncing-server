class CustomLogFormatter < ActiveSupport::Logger::SimpleFormatter
  SEVERITY_TO_COLOR_MAP = {
    'DEBUG' => '0;37',
    'INFO' => '32',
    'WARN' => '33',
    'ERROR' => '31',
    'FATAL' => '31',
    'UNKNOWN' => '37',
  }.freeze

  IP_REGEXP = /\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b/.freeze
  FILTERED_STRING = '**FILTERED**'.freeze

  def call(severity, time, _progname, msg)
    formatted_severity = format('%-5s', severity.to_s)
    formatted_time = time.strftime('%Y-%m-%d %H:%M:%S.') << time.usec.to_s[0..2].rjust(3)
    color = SEVERITY_TO_COLOR_MAP[severity]

    "\033[0;37m#{formatted_time}\033[0m [\033[#{color}m#{formatted_severity}\033[0m] #{filter_ip(msg)} (pid:#{$PID})\n"
  end

  def filter_ip(msg)
    if msg.is_a? String
      msg.gsub(IP_REGEXP, FILTERED_STRING).strip
    else
      msg
    end
  end
end
