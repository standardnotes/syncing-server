class MigrateDropboxToExtServer < ActiveRecord::Migration[5.0]
  def change
    # this migration migrates current users who are using the Dropbox extension
    # which was once part of this project, to the dedicated extension server

    extensions = Item.where(:content_type => "SF|Extension")
    extensions.each do |ext|
      if !ext.content
        next
      end
      string = ext.content[3..ext.content.length]
      decoded = Base64.decode64(string)
      obj = JSON.parse(decoded)
      url = obj["url"]
      url.sub!("#{ENV["HOST"]}/ext", ENV["EXTENSIONS_SERVER"])

      new_string = "000" + Base64.encode64(obj.to_json)
      ext.content = new_string
      ext.save
    end

  end
end
