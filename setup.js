const fs = require('fs');
const prompts = require('prompts');
const ora = require('ora');

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
  spinner.succeed('Environment variables setup.');
})
  .then(() => {
    const exec = require('child_process').exec;
    spinner.start('Building docker containers...');
    exec(`docker-compose up -d`, (error, stdout, stderr) => {
      if (error) {
        spinner.fail(`Error building docker containers: ${error}`);
        process.exit();
      } else {
        spinner.succeed('Docker containers built.');
        spinner.start('Copying password data to percona for import...');
        exec(`docker cp tmp/data/pwned-passwords.txt hibp_percona:/tmp/pwned-passwords.txt`, (err, stdout, stderr) => {
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
  .catch((err) => {
    console.log(err);
    process.exit();
  });
