require 'aws-sdk-sns'
require 'zlib'

class SnsPublisher
  attr_accessor :sns_client, :topic_arn

  MAIL_BACKUP_ATTACHMENT_TOO_BIG = 'MAIL_BACKUP_ATTACHMENT_TOO_BIG'.freeze
  SYNCING_SERVER_SOURCE_TYPE = 'application'.freeze
  SYNCING_SERVER_SOURCE_ID = 'syncing-server'.freeze

  def initialize
    @sns_client = Aws::SNS::Client.new
    @topic_arn = ENV.fetch('SNS_TOPIC_ARN', nil)
  end

  def publish_mail_backup_attachment_too_big(email, allowed_size)
    unless @topic_arn
      Rails.logger.warn 'SNS topic arn has not been configured. Skipped publishing to SNS.'

      return
    end

    begin
      sns_response = @sns_client.publish(
        topic_arn: @topic_arn,
        message: compress_message(MAIL_BACKUP_ATTACHMENT_TOO_BIG, email, allowed_size),
        message_attributes: {
          'compression' => {
            data_type: 'String',
            string_value: 'true',
          },
          'event' => {
            data_type: 'String',
            string_value: MAIL_BACKUP_ATTACHMENT_TOO_BIG,
          },
        }
      )

      Rails.logger.info "Published event #{MAIL_BACKUP_ATTACHMENT_TOO_BIG} to SNS: #{sns_response.message_id}"
    rescue StandardError => e
      Rails.logger.error "Could not publish SNS event: #{e.message}"
    end
  end

  def compress_message(event, email, allowed_size)
    event = {
      type: event,
      meta: {
        correlation: {
          email: email,
        },
        creationDate: Time.now,
        sourceType: SYNCING_SERVER_SOURCE_TYPE,
        sourceId: SYNCING_SERVER_SOURCE_ID,
        messageId: '',
        version: '1',
      },
      payload: {
        allowedSize: allowed_size,
      },
    }

    Base64.encode64(Zlib::Deflate.deflate(JSON.dump(event)))
  end
end
