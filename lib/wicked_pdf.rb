# wkhtml2pdf Ruby interface
# http://wkhtmltopdf.org/

require 'logger'
require 'digest/md5'
require 'rbconfig'

if (RbConfig::CONFIG['target_os'] =~ /mswin|mingw/) && (RUBY_VERSION < '1.9')
  require 'win32/open3'
else
  require 'open3'
end

begin
  require 'active_support/core_ext/module/attribute_accessors'
rescue LoadError
  require 'active_support/core_ext/class/attribute_accessors'
end

begin
  require 'active_support/core_ext/object/blank'
rescue LoadError
  require 'active_support/core_ext/blank'
end

require 'wicked_pdf/version'
require 'wicked_pdf/railtie'
require 'wicked_pdf/tempfile'
require 'wicked_pdf/middleware'

require 'wicked_pdf/rendering/wkhtmltopdf'
require 'wicked_pdf/rendering/chrome'

class WickedPdf
  @@config = {}
  cattr_accessor :config
  attr_accessor :binary_version, :renderer

  def initialize(binary_path = nil)
   @renderer = case WickedPdf.config[:preference]
   when 'wkhtmltopdf'
    WickedPdfRendering::Wkhtmltopdf.new(binary_path)
   when 'chrome' 
    WickedPdfRendering::Chrome.new(binary_path)
   else
    WickedPdfRendering::Wkhtmltopdf.new(binary_path)
   end
  end

  def pdf_from_html_file(filepath, options = {})
    pdf_from_url("file:///#{filepath}", options)
  end

  def pdf_from_string(string, options = {})
    options = options.dup
    options.merge!(WickedPdf.config) { |_key, option, _config| option }
    string_file = WickedPdfTempfile.new('wicked_pdf.html', options[:temp_path])
    string_file.binmode
    string_file.write(string)
    string_file.close

    pdf = pdf_from_html_file(string_file.path, options)
    pdf
  ensure
    string_file.close! if string_file
  end

  def pdf_from_url(url, options = {})
    # merge in global config options
    options.merge!(WickedPdf.config) { |_key, option, _config| option }
    generated_pdf_file = WickedPdfTempfile.new('wicked_pdf_generated_file.pdf', options[:temp_path])
    command = renderer.build_command(url, options, generated_pdf_file)

    print_command(command.inspect) if in_development_mode?

    err = Open3.popen3(*command) do |_stdin, _stdout, stderr|
      stderr.read
    end
    if options[:return_file]
      return_file = options.delete(:return_file)
      return generated_pdf_file
    end
    generated_pdf_file.rewind
    generated_pdf_file.binmode
    pdf = generated_pdf_file.read
    raise "Error generating PDF\n Command Error: #{err}" if options[:raise_on_all_errors] && !err.empty?
    raise "PDF could not be generated!\n Command Error: #{err}" if pdf && pdf.rstrip.empty?
    pdf
  rescue StandardError => e
    raise "Failed to execute:\n#{command}\nError: #{e}"
  ensure
    generated_pdf_file.close! if generated_pdf_file && !return_file
  end

  private

  def in_development_mode?
    return Rails.env == 'development' if defined?(Rails.env)
    RAILS_ENV == 'development' if defined?(RAILS_ENV)
  end

  def print_command(cmd)
    Rails.logger.debug '[wicked_pdf]: ' + cmd
  end
end
