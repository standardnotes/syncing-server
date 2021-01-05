require 'redis'

if ENV['REDIS_HOST'].present? && ENV['REDIS_PORT'].present?
  Redis.current = Redis.new(host: ENV['REDIS_HOST'], port: ENV['REDIS_PORT'])
end
