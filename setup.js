const fs = require('fs');
const prompts = require('prompts');
const ora = require('ora');

const exec = require('child_process').exec;
const execSync = require('child_process').execSync;
const spinner = ora('Setting up environment...');

let questions = [
  {
    type: 'text',
    name: 'mysql_username',
    message: 'Enter a username for MySQL (default: "hibp"):',
  },
  {
    type: 'password',
    name: 'mysql_password',
    message: 'Enter a password for MySQL (default: "password":',
  }
];

prompts(questions).then((response) => {
  const defaults = {
    mysql_username: 'hibp',
    mysql_password: 'password',
  };
  if (`${response.mysql_username}`.length <= 0) response.mysql_username = defaults.mysql_username;
  if (`${response.mysql_password}`.length <= 0) response.mysql_password = defaults.mysql_password;

  const env_file_stream = fs.createWriteStream('.env');
  env_file_stream.once('open', function(_) {
    env_file_stream.write("MYSQL_RANDOM_ROOT_PASSWORD=yes\n");
    env_file_stream.write("MYSQL_DATABASE=hibp_local\n");
    env_file_stream.write(`MYSQL_USER=${response.mysql_username}\n`);
    env_file_stream.write(`MYSQL_PASSWORD=${response.mysql_password}\n`);
    env_file_stream.end();
  });
  execSync('source .env');
  spinner.succeed('Environment variables setup.');
})
  .then(() => {
    execSync('echo $MYSQL_USER');
    spinner.start('Building database container...');
    return exec('docker build -t hibp-local/percona --build-arg MYSQL_USER=$MYSQL_USER --build-arg MYSQL_PASSWORD=$MYSQL_PASSWORD .', (error, stdout, stderr) => {
      if (error) {
        spinner.fail(`Error building docker containers: ${error}`);
        process.exit();
      } else {
        spinner.succeed('Docker containers built.');
        spinner.start('Starting docker container...');
        execSync('yarn run start');
        spinner.succeed('Docker containers built.');
        spinner.start('Copying password data to percona for import...');
        exec(`docker cp import.sql tmp/data/pwned-passwords.txt hibp-local:/tmp/`, (err, stdout, stderr) => {
          if (err) {
            spinner.fail(`Error copying password data to hibp_percona container: ${err}`);
          } else {
            spinner.succeed('HIBP password data copied to hibp_percona container.');
          }
          process.exit();
        });
      }
    });
  })
  .then(() => {
  })
  .catch((err) => {
    console.log(err);
    process.exit();
  });
