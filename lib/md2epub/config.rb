
module Md2Epub

  class Config
    attr_accessor :md_files, :tx_files,
                  :booktitle, :bookname, :aut, :publisher,
                  :directories

    def initialize(conf, path)
      tmpdir  = Dir.mktmpdir('md2epub', path)

      @bookname    = conf['bookname'] || 'md2epub'
      @booktitle   = conf['booktitle']
      @aut         = conf['aut']
      @publisher   = conf['publisher']
      @directories = Directories.new(path, tmpdir)

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
      def initialize(path, tmpdir)
        @resource = path
        @asset    = File.dirname(__FILE__) + '/../../assets/'
        @tmp      = tmpdir
        @content  = File.join(tmpdir, '/OEBPS/text')
      end
    end
  end
end
