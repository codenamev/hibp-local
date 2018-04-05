require 'open-uri'

namespace :hibp do
  desc "Download the latest snapshot of HIBP hashes"
  task :download => :environment do
    class OS
      def self.windows?
        (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
      end

      def self.mac?
      (/darwin/ =~ RUBY_PLATFORM) != nil
      end

      def self.unix?
        !windows?
      end

      def self.linux?
        unix? && !mac?
      end

      def self.package_manager
        return "brew" if mac?
        return "apt-get" if linux?
      end
    end

    class HIBPSnapshotDownloader
      LAST_SNAPSHOT_FILE_EXT = "7z"
      LAST_SNAPSHOT_FILENAME = "pwned-passwords-2.0.txt.7z"
      EXTRACTED_SNAPSHOT_FILENAME = "pwned-passwords-2.0.txt"
      LAST_SNAPSHOT_URL = "https://downloads.pwnedpasswords.com/passwords/#{LAST_SNAPSHOT_FILENAME}"
      LAST_SNAPSHOT_SHA = "c267424e7d2bb5b10adff4d776fa14b0967bf0cc"
      CACHED_DOWNLOAD_PATH = "#{Rails.root}/tmp"
      CACHED_DATA_PATH = "#{Rails.root}/tmp/data"
      LAST_SNAPSHOT_DESTINATION_PATH = "#{CACHED_DOWNLOAD_PATH}/#{LAST_SNAPSHOT_FILENAME}"
      EXTRACTED_SNAPSHOT_PATH = "#{CACHED_DATA_PATH}/#{EXTRACTED_SNAPSHOT_FILENAME}"
      FINAL_IMPORTABLE_CSV_PATH = "#{CACHED_DATA_PATH}/pwned-passwords.csv"
      DOWNLOAD_TIMEOUT = 3600

      attr_reader :last_snapshot_sha, :logger, :spinners, :checksum_spinner, :extraction_spinner, :snapshot_conversion_spinner, :download_spinner, :prompt, :pastel

      def initialize(sha = LAST_SNAPSHOT_SHA)
        @last_snapshot_sha = sha
        # Setup logger
        @logger = Logger.new("#{Rails.root}/log/download.log")
        # Loading helpers
        @spinners = TTY::Spinner::Multi.new("[:spinner] Updating your HIBP hashes snapshot")
        @checksum_spinner = @spinners.register "[:spinner] Verifying checksum for SHA #{@last_snapshot_sha}... "
        @snapshot_conversion_spinner = @spinners.register "[:spinner] Converting snapshot to CSV... "
        @download_spinner = @spinners.register "[:spinner] Downloading latest HIBP data... "
        @extraction_spinner = @spinners.register "[:spinner] Extracting HIBP archive... "
        @prompt = TTY::Prompt.new
        @pastel = Pastel.new
        check_requirements!
      end


      def check_requirements!
        require_and_ask_to_install command: "7za", source_package: "p7zip"
        require_and_ask_to_install command: "shasum"
        run_command "touch #{Rails.root}/log/download.log"
        run_command "touch #{Rails.root}/log/download-shell.log"
      end

      def require_and_ask_to_install(command:, source_package: nil)
        return if command_exists?(command)
        return prompt.say "#{pastel.red("#{command} required")}" if source_package.blank? || OS.package_manager.blank?
        install_command = "#{OS.package_manager} install #{source_package}"
        continue_with_install = prompt.yes?("#{command} is not installed, would you like us to install it?\n(we'll run: \`#{install_command}\`")
        if !continue_with_install
          prompt.say "#{pastel.red("#{command} required")}; install with \`#{install_command}\`"
          prompt.say pastel.red("download aborted")
          exit
        else
          run_command "#{install_command}"
          unless $?.success?
            prompt.say pastel.red("Unable to install #{source_package}.")
            exit
          end
        end
      end

      def command_exists?(cmd)
        `command -v #{cmd}`.strip.present?
      end

      def run_command(cmd)
        `#{cmd} &>#{Rails.root}/log/download-shell.log`
      end

      def extract_snapshot
        if File.exists?(EXTRACTED_SNAPSHOT_PATH)
          extraction_spinner.success "(skipped) – already extracted"
          return
        end

        run_command "mkdir -p #{CACHED_DATA_PATH}"
        run_command "7za e -y -o#{CACHED_DATA_PATH} #{LAST_SNAPSHOT_DESTINATION_PATH}"
        unless $?.success?
          extraction_spinner.error pastel.red("(error)") + " failed to extracted the downloaded snapshot"
          exit
        end
        extraction_spinner.success pastel.green("Extracted!") + " Saved to #{LAST_SNAPSHOT_DESTINATION_PATH}"
      end

      def convert_snapshot_to_csv
        if File.exists?(FINAL_IMPORTABLE_CSV_PATH)
          snapshot_conversion_spinner.success "(skipped) converted CSV snapshot found"
          return
        end

        run_command "sed -i 's/\:/,/g' #{EXTRACTED_SNAPSHOT_PATH} && mv #{EXTRACTED_SNAPSHOT_PATH} #{FINAL_IMPORTABLE_CSV_PATH}"
        unless $?.success?
          snapshot_conversion_spinner.error "(error converting to CSV)"
          exit
        end
        snapshot_conversion_spinner.success pastel.green("Converted!") + " Saved it to: #{FINAL_IMPORTABLE_CSV_PATH}"
      end

      def verify_checksum
        if File.exists?(FINAL_IMPORTABLE_CSV_PATH)
          prompt.say "(skipped) cached snapshot found"
          return
        end

        shasum = `shasum #{LAST_SNAPSHOT_DESTINATION_PATH} | awk '{ print $1}'`.strip
        if shasum =~ /#{last_snapshot_sha}/
          checksum_spinner.success("(verified)")
        else
          checksum_spinner.error "(NOT verified) downloaded snapshot sha: #{shasum}"
          prompt.say pastel.red("downloaded file processing aborted")
          exit
        end

        unless $?.success?
          spinner.error"(Downloaded file not verified.  Please verify the checksum of the file manually, and proceed with caution)"
          exit
        end
      end

      def download!
        start_spinners
        if File.exists?(LAST_SNAPSHOT_DESTINATION_PATH)
          download_spinner.success "(skipped) Snapshot already downloaded, and saved to #{LAST_SNAPSHOT_DESTINATION_PATH}"
          return process_downloaded_archive
        end

        begin
          progress_bar = nil
          IO.copy_stream(
            open(
              LAST_SNAPSHOT_URL,
              read_timeout: DOWNLOAD_TIMEOUT,
              content_length_proc: lambda { |size|
                progress_bar = TTY::ProgressBar.new("[:bar]", total: size)
              },
              progress_proc: lambda { |size|
                progress_bar.current = size if progress_bar
              }
             ),
            LAST_SNAPSHOT_DESTINATION_PATH
          )
          download_spinner.success pastel.green("complete") + " Latest HIBP data successfully saved to: #{LAST_SNAPSHOT_DESTINATION_PATH}"
          process_downloaded_archive
        rescue TTY::Command::ExitError => e
          download_spinner.error pastel.red("Unable to download file")
          raise e
        end
      end

      def start_spinners
        spinners.auto_spin
        download_spinner.auto_spin
        checksum_spinner.auto_spin
        extraction_spinner.auto_spin
        snapshot_conversion_spinner.auto_spin
      end

      def process_downloaded_archive
        verify_checksum
        extract_snapshot
        convert_snapshot_to_csv
      end
    end

    HIBPSnapshotDownloader.new.download!

  end
end
