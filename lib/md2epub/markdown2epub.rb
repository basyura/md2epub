
module Md2Epub

  class Markdown2EPUB

    def initialize(path)
      file = File.dirname(__FILE__) + '/../../mdfiles/epub.yaml'
      raise "Can't open #{file}." if file.nil? || !File.exist?(file)
      @config = Config.new(YAML.load_file(file), path)
    end

    def build
      puts %Q(BUILD::#{@config.resourcedir})
      conf = @config
      # setup files
      setup(conf.contentdir, conf.assetdir, conf.resourcedir, conf.tmpdir)
      # convert to html from md and textile
      pages = to_html(conf.resourcedir, conf.contentdir, conf.tmpdir, conf.md_files, conf.tx_files)
      # generate epub
      build_epub(conf.bookname, pages, conf.assetdir, conf.resourcedir, conf.tmpdir)
      # optional process
      post_process(conf.tmpdir)
    end   

    private

    def setup(contentdir, assetdir, resourcedir, tmpdir)
      # copy
      copy_asset_files(assetdir, tmpdir)
      copy_images(resourcedir, tmpdir)
      # make HTML directory
      FileUtils.mkdir(contentdir)
    end

    def to_html(resourcedir, contentdir, tmpdir, md_files, tx_files)
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
      rndr   = Redcarpet::Markdown.new(Redcarpet::Render::XHTML, *options)
      # Fetch Image Class
      images = ImageFetcher.new(tmpdir, resourcedir)

      # markdown to HTML
      pages = md_files_to_html(rndr, images, md_files, contentdir)
      # textile tos HTML
      pages = pages + textile_to_html(rndr, images, tx_files, contentdir)
      # sort by filename
      pages.sort! { |a, b| a[:file] <=> b[:file] }
      pages
    end

    def build_epub(bookname, pages, assetdir, resourcedir, tmpdir)
      # build EPUB meta files
      build_opf(pages, assetdir, tmpdir)
      build_toc(pages, assetdir, tmpdir)
      # build cover page
      build_cover(pages, assetdir, tmpdir)
      # ZIP!
      make_epub(bookname, tmpdir, resourcedir)
    end

    def post_process(tmpdir, debug = false)
      # delete working directory
      unless debug
        FileUtils.remove_entry_secure tmpdir
      end
    end

    def md_files_to_html(rndr, images, files, contentdir)
      get_title = Regexp.new('^[#=] (.*)$')
      pages = files.inject([]) do |pages, file|
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
        build_page( page, html, %Q(#{contentdir}/#{fname}) )

        pages.push page
      end           
      pages
    end

    def textile_to_html(rndr, images, files, contentdir)
      get_title = Regexp.new('^h1. (.*)$')
      pages = files.inject([]) do |pages, file|
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
        build_page( page, html, %Q(#{contentdir}/#{fname}) )

        pages.push page
      end
      pages
    end

    def copy_asset_files(assetdir, tmpdir)
      FileUtils.copy(assetdir + 'mimetype', tmpdir)
      FileUtils.cp_r(Dir.glob(assetdir + 'META-INF'), tmpdir)
      FileUtils.cp_r(Dir.glob(assetdir + 'OEBPS'   ), tmpdir)
    end    


    def copy_images(resourcedir, tmpdir)
      origin_imagedir = resourcedir + "/images"
      if File.exists?( origin_imagedir )
        epub_imagedir = tmpdir + "/OEBPS/"
        FileUtils.makedirs( epub_imagedir )
        FileUtils.cp_r(Dir.glob( origin_imagedir ), epub_imagedir)
      end
    end

    def build_page(page, pagebody, file)
      pagetitle = page[:pagetitle]        
      erbfile   = @config.assetdir + "page.xhtml.erb"

      open(erbfile, 'r') do |erb|
        html = ERB.new( erb.read , nil, '-').result(binding)
        open( file, "w") do |f|
          f.write( html )
        end
      end
    end

    def build_opf(pages, assetdir, tmpdir)
      erbfile = assetdir + 'content.opf.erb'

      imagelist = []        
      Dir.glob(tmpdir + '/OEBPS/images/*') do |img|
        imagelist.push({
          :fname =>  File.basename(img),
          :mediatype => MIME::Types.type_for(img)[0].to_s 
        })
      end

      open(erbfile, 'r') do |erb|
        opf = ERB.new(erb.read , nil, '-').result(binding)
        open(tmpdir + '/OEBPS/content.opf', 'w') do |f|
          f.write(opf)
        end
      end
    end

    def build_toc(pages, assetdir, tmpdir)
      erbfile = assetdir + 'toc.xhtml.erb'
      open(erbfile, 'r') do |erb|
        html = ERB.new(erb.read , nil, '-').result(binding)
        open(tmpdir + '/OEBPS/toc.xhtml', 'w') do |f|
          f.write( html )
        end
      end
    end    

    def build_cover(pages, assetdir, tmpdir)
      erbfile = assetdir + 'cover.html.erb'
      open(erbfile, 'r') do |erb|
        html = ERB.new(erb.read , nil, '-').result(binding)
        open(tmpdir + '/OEBPS/text/cover.xhtml', 'w') do |f|
          f.write( html )
        end
      end
    end       

    def make_epub(bookname, tmpdir, resourcedir)
      fork do
        Dir.chdir(tmpdir) do |d|
          exec("zip", "-0X", "#{bookname}", "mimetype")
        end
      end
      Process.waitall
      fork do
        Dir.chdir(tmpdir) do |d|
          exec("zip -Xr9D #{bookname}" + ' * -x "*.DS_Store" -x mimetype META-INF OEBPS')
        end
      end
      Process.waitall
      FileUtils.cp( %Q(#{tmpdir}/#{bookname}), resourcedir)
    end
  end
end
