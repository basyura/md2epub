
module Md2Epub

  class Config
    attr_accessor :md_files, :tx_files,
                  :booktitle, :bookname, :uuid, :aut, :publisher, :pubdate,
                  :directories, :debug

    def initialize(conf, path)
      @bookname    = conf['bookname'] || 'md2epub'
      @booktitle   = conf['booktitle']
      @aut         = conf['aut']
      @lang        = conf['lang']
      @publisher   = conf['publisher']
      @debug       = conf['debug']
      @directories = Directories.new

      if conf.key?('uuid') then
        @uuid = UUIDTools::UUID.sha1_create(UUID_DNS_NAMESPACE, conf['uuid']).to_s
      else
        @uuid = UUIDTools::UUID.random_create.to_s
      end
      @pubdate = conf.key?('pubdate') ? conf['pubdate'] : Time.now.gmtime.iso8601

      if File.directory?(path)
        @md_files = Dir::glob("#{path}/*.{md,mkd,markdown}")
        @tx_files = Dir::glob("#{path}/*.textile")
      elsif path =~ /.*\.(md|mkd|markdown)/
        @md_files = [path] 
      elsif path =~ /.*\.textile/
        @tx_files = [path]
      else
        raise ArgumentError.new('wrong path : ' + path)
      end
    end

    class Directories
      attr_reader :resource, :asset, :tmp, :content
      def initialize
        @resource = Dir.pwd
        @asset    = File.dirname(__FILE__) + '/../../assets/'
        @tmp      = Dir.mktmpdir("md2epub", Dir.pwd)
        @content  = @tmp + '/OEBPS/text'
      end
    end
  end
end
