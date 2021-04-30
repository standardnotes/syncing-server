require 'openssl'

class SmimeInterceptor
  class << self
    include OpenSSL

    def delivering_email(message)
      signed_message = sign(message.encoded)
      overwrite_body(message, signed_message)
      overwrite_headers(message, signed_message)
    end

    private

    def overwrite_body(message, signed_message)
      message.body = nil
      message.body = signed_message.body.encoded
    end

    def overwrite_headers(message, signed_message)
      message.content_disposition = signed_message.content_disposition if signed_message.content_disposition
      message.content_transfer_encoding = signed_message.content_transfer_encoding
      message.content_type = signed_message.content_type
    end

    def sign(data)
      Mail.new(PKCS7.write_smime(PKCS7.sign(certificate, private_key, data, [], PKCS7::DETACHED)))
    end

    def certificate
      @certificate ||= X509::Certificate.new(File.read(Rails.configuration.smime[:certfilename]))
    end

    def private_key
      @private_key ||= PKey::RSA.new(File.read(Rails.configuration.smime[:keyfilename]))
    end
  end
end
