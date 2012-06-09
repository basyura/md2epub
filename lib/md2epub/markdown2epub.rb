
module Md2Epub

  class Markdown2EPUB

    def initialize(path)
      file = File.dirname(__FILE__) + '/../../mdfiles/epub.yaml'
      raise "Can't open #{file}." if file.nil? || !File.exist?(file)
      @config = Config.new(YAML.load_file(file), path)
    end

    def build
      puts %Q(BUILD::#{@config.resourcedir})
      # markdown Render options
      options = [
        :autolink            => true,
        :fenced_code         => true,
        :fenced_code_blocks  => true,
        :gh_blockcode        => true,
        :hard_wrap           => true,
        :lax_html_blocks     => true,
        :no_intra_emphasis   => true,
        :no_intraemphasis    => true,
        :space_after_headers => true,
        :strikethrough       => true,
        :superscript         => true,
        :tables              => true,
        :xhtml               => true
      ]
      rndr = Redcarpet::Markdown.new(Redcarpet::Render::XHTML, *options )

      # Fetch Image Class
      images = ImageFetcher.new( @config.tmpdir, @config.resourcedir )

      # copy Asset Files
      _copy_asset_files()

      # copy Resource Images
      _copy_images()

      # make HTML directory
      contentdir = @config.tmpdir + "/OEBPS/text"
      FileUtils.mkdir( contentdir )

      # markdown to HTML
      get_title = Regexp.new('^[#=] (.*)$')

      @config.md_files.each do |file|
        # puts "#{file}: #{File::stat(file).size} bytes"
        md = File.read( file )
        html =""

        get_title =~ md
        if $1 then
          pagetitle = $1.chomp
          md[ get_title ] = ""
        else 
          pagetitle = File.basename(file, ".*")
        end
        fname = File.basename(file, ".md") << ".xhtml"
        page = {:pagetitle => pagetitle, :file => fname }                

        # render markdown
        html = rndr.render( md )

        # Fetch Images and replace src path
        html = images.fetch( html )
        _build_page( page, html, %Q(#{contentdir}/#{fname}) )

        @config.pages.push page
      end           

      # textile to HTML
      get_title = Regexp.new('^h1. (.*)$')

      @config.tx_files.each do |file|
        # puts "#{file}: #{File::stat(file).size} bytes"
        textile = File.read( file )
        html    =""

        get_title =~ textile
        if $1
          pagetitle = $1.chomp
          md[ get_title ] = ""
        else 
          pagetitle = File.basename(file, ".*")
        end
        fname = File.basename(file, ".textile") << ".xhtml"
        page = {:pagetitle => pagetitle, :file => fname }                

        # render textile
        html = RedCloth.new( textile ).to_html            

        # Fetch Images and replace src path
        html = images.fetch( html )
        _build_page( page, html, %Q(#{contentdir}/#{fname}) )

        @config.pages.push page
      end

      # sort by filename
      @config.pages.sort! {|a, b| a[:file] <=> b[:file]}

      # build EPUB meta files
      _build_opf()
      _build_toc()

      # build cover page
      _build_cover()

      # ZIP!
      make_epub( @config.tmpdir , @config.bookname )

      # delete working directory
      unless @config.debug then
        FileUtils.remove_entry_secure(@config.tmpdir)
      end
    end   

    private

    def _copy_asset_files
      FileUtils.copy(@config.assetdir + "mimetype", @config.tmpdir)
      FileUtils.cp_r(Dir.glob( @config.assetdir + "META-INF"), @config.tmpdir)
      FileUtils.cp_r(Dir.glob( @config.assetdir + "OEBPS"), @config.tmpdir)
    end    


    def _copy_images
      origin_imagedir = @config.resourcedir + "/images"
      if File.exists?( origin_imagedir )
        epub_imagedir = @config.tmpdir + "/OEBPS/"
        FileUtils.makedirs( epub_imagedir )
        FileUtils.cp_r(Dir.glob( origin_imagedir ), epub_imagedir)
      end
    end


    def _build_page( page, pagebody, file )
      html      = ""
      pagetitle = page[:pagetitle]        
      erbfile   = @config.assetdir + "page.xhtml.erb"

      open(erbfile, 'r') do |erb|
        html = ERB.new( erb.read , nil, '-').result(binding)
        open( file, "w") do |f|
          f.write( html )
        end
      end
    end


    def _build_opf
      opf     = ""
      pages   = @config.pages
      erbfile = @config.assetdir + "content.opf.erb"

      imagelist = []        
      Dir.glob( @config.tmpdir + "/OEBPS/images/*" ) do |img|
        imagelist.push({
          :fname =>  File.basename(img),
          :mediatype => MIME::Types.type_for(img)[0].to_s 
        })
      end

      open(erbfile, 'r') do |erb|
        opf = ERB.new( erb.read , nil, '-').result(binding)
        open( @config.tmpdir + "/OEBPS/content.opf", "w") do |f|
          f.write( opf )
        end
      end
    end


    def _build_toc
      html    = ""
      pages   = @config.pages
      erbfile = @config.assetdir + "toc.xhtml.erb"

      open(erbfile, 'r') do |erb|
        html = ERB.new( erb.read , nil, '-').result(binding)
        open( @config.tmpdir + "/OEBPS/toc.xhtml", "w") do |f|
          f.write( html )
        end
      end
    end    

    def _build_cover
      html    = ""
      pages   = @config.pages
      erbfile = @config.assetdir + "cover.html.erb"

      open(erbfile, 'r') do |erb|
        html = ERB.new( erb.read , nil, '-').result(binding)
        open( @config.tmpdir + "/OEBPS/text/cover.xhtml", "w") do |f|
          f.write( html )
        end
      end
    end       

    def make_epub( tmpdir , epubfile)
      fork do
        Dir.chdir(tmpdir) do |d|
          exec("zip", "-0X", "#{epubfile}", "mimetype")
        end
      end
      Process.waitall
      fork do
        Dir.chdir(tmpdir) do |d|
          exec("zip -Xr9D #{epubfile}" + ' * -x "*.DS_Store" -x mimetype META-INF OEBPS')
        end
      end
      Process.waitall
      FileUtils.cp( %Q(#{tmpdir}/#{epubfile}), @config.resourcedir)
    end
  end
end
