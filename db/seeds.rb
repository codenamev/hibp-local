LOG_FILE = "#{Rails.root}/log/import-shell.log"
FINAL_IMPORTABLE_CSV_PATH = "#{Rails.root}/tmp/data/pwned-passwords.csv"
raise "HIBP CSV snapshot not found.  Please plase at #{FINAL_IMPORTABLE_CSV_PATH}" unless File.exist?(FINAL_IMPORTABLE_CSV_PATH)

def run_command(cmd)
  `#{cmd} &>#{LOG_FILE}`
end

prompt         = TTY::Prompt.new
pastel         = Pastel.new
import_spinner = TTY::Spinner.new("[:spinner] Importing CSV to your local database...")
mysql_host     = Rails.configuration.database_configuration.fetch(Rails.env).fetch("host")
mysql_user     = Rails.configuration.database_configuration.fetch(Rails.env).fetch("username")

import_spinner.auto_spin

run_command("mysql -h #{mysql_host} -u #{mysql_user} < #{Rails.root}/db/import.sql")
unless $?.success?
  prompt.say pastel.red("Unable to import CSV. For details, check #{LOG_FILE}")
  exit
end

import_spinner.success pastel.green("HIBP hashes imported successfully!")
