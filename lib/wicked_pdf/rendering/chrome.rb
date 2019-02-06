module WickedPdfRendering
  class Chrome
    EXE_NAME = 'wicked-chrome'.freeze

    def initialize(binary_path = nil)
      @exe_path = binary_path || find_wicked_chrome_binary_path
      raise "Location of #{EXE_NAME} unknown" if @exe_path.empty?
      raise "Bad #{EXE_NAME}'s path: #{@exe_path}" unless File.exist?(@exe_path)
      raise "#{EXE_NAME} is not executable" unless File.executable?(@exe_path)
    end

    def build_command(url, options, generated_pdf_file)
      command = [@exe_path, 'pdf']
      command << url
      command << generated_pdf_file.path.to_s
    end

    private

    def find_wicked_chrome_binary_path
      possible_locations = (ENV['PATH'].split(':') + %w[/usr/bin /usr/local/bin]).uniq
      possible_locations += %w[~/bin] if ENV.key?('HOME')
      exe_path ||= begin
        detected_path = (defined?(Bundler) ? Bundler.which('wicked-chrome') : `which wicked-chrome`).chomp
        detected_path.present? && detected_path
      rescue StandardError
        nil
      end
      exe_path ||= possible_locations.map { |l| File.expand_path("#{l}/#{EXE_NAME}") }.find { |location| File.exist?(location) }
      exe_path || ''
    end
  end
end