const ora = require('ora');
const fetch = require('node-fetch');
const fs = require('fs');
const last_snapshot_filename = "pwned-passwords-2.0.txt.7z"
const last_snapshot_url = `https://downloads.pwnedpasswords.com/passwords/${last_snapshot_filename}`
const last_snapshot_sha = "c267424e7d2bb5b10adff4d776fa14b0967bf0cc";
const last_snapshot_destination_path = `./tmp/${last_snapshot_filename}`;
const FILE_DOWNLOAD_TIMEOUT = 7200000; // 2 hrs

const spinner = ora('Downloading latest HIBP data...').start();

const verifyChecksum = () => {
  spinner.start(`Verifying checksum... ${last_snapshot_sha}`);
  const exec = require('child_process').exec;
  exec(`shasum ${last_snapshot_destination_path} | awk '{ print $1}'`, (err, out, code) => {
    if (out.includes(last_snapshot_sha)) {
      spinner.succeed('Downloaded file verified.');
    } else {
      spinner.fail('Downloaded file not verified.  Please verify the checksum of the file manually, and proceed with caution.');
    }
    process.exit();
  });
};

if (fs.existsSync(last_snapshot_destination_path)) {
  spinner.succeed(`Latest HIBP data already saved to: ${last_snapshot_destination_path}`);
  verifyChecksum();
}

fetch(last_snapshot_url)
  .then(res => {
    const download_stream = fs.createWriteStream(last_snapshot_destination_path);
    let timer;

    return new Promise((resolve, reject) => {
      const errorHandler = (error) => {
        reject({ reason: 'Unable to download file', meta: { url: last_snapshot_url, error }})
      };

      res.body
        .on('error', errorHandler)
        .pipe(download_stream);

      download_stream.on('error', errorHandler)
        .on('open', () => {
          timer = setTimeout(() => {
            download_stream.close()
            reject({ error: 'Timed out downloading file', meta: { url: last_snapshot_url }})
          }, FILE_DOWNLOAD_TIMEOUT)
        })
        .on('finish', () => {
          resolve(last_snapshot_destination_path)
        })
    })
      .then((destPath) => {
        clearTimeout(timer);
        return destPath;
      }, (err) => {
        clearTimeout(timer);
        return Promise.reject(err);
      });
  })
  .then(destPath => {
    spinner.succeed(`Latest HIBP data successfully saved to: ${destPath}`);
    verifyChecksum();
  }, (err) => {
    spinner.fail(err.reason);
    spinner.fail(err.meta.error);
    process.exit();
  });
