
module Md2Epub

  class ImageFetcher

    def initialize( tmpdir , resourcedir)
      @text        = []
      @basedir     = resourcedir
      @resourcedir = @basedir
      @assetdir    = File.dirname(__FILE__) + '/../../assets/'
      @imagedir    = tmpdir + "/OEBPS/images/"
      @imglist     = []
      FileUtils.makedirs(@imagedir)
    end

    def _fetchImage( url, filename )

      @imglist.each do |img|
        if img[:url] == url
          puts "already :" + url
          return nil
        end
      end

      open(@imagedir + filename, 'wb') do |file|
        open(url) do |data|
          file.write(data.read)
          puts "fetch :" + url
        end
      end
      return true
    end    

    def fetch( text )

      pwd = Dir::pwd
      Dir::chdir(@resourcedir)

      # Regexp image URL
      reg = /img.+src=[\"|\']?([\-_\.\!\~\*\'\(\)a-zA-Z0-9\;\/\?\:@&=\$\,\%\#]+\.(jpg|jpeg|png|gif|bmp))/i

      text.scan(reg).each do |item|
        url = item[0]
        id  = Digest::MD5.new.update(item[0]).to_s
        filename = %Q(#{id}.#{item[1]})

        p url

        if _fetchImage( url, filename )
          img =  {
            :url => url,
            :id => id,
            :file => filename
          }
          @imglist.push(img)
        end            
        apimgfile = "../images/" + filename
        text.gsub!(url , apimgfile)
      end

      Dir::chdir(pwd)
      text
    end
  end
end
