# Standard Notes Syncing Server

You can run your own Standard Notes server and use it with any Standard Notes app. This allows you to have 100% control of your data. This server is built with Ruby on Rails and can be deployed in minutes.

**Requirements**

- Ruby 2.3+
- Rails 5
- MySQL 5.6+ database

### Getting started

1. Clone the project:

	```
	git clone --branch master https://github.com/standardnotes/syncing-server.git
	```

1. Create a `.env` file in the project's root directory. See [.env.sample](.env.sample) for required values.

1. Initialize the project:

	```
	bundle install
	bundle exec rails db:create db:migrate
	```

1. Start the server:

	```
	bundle exec rails server
	```

### Tests

The `syncing-server` uses [RSpec](http://rspec.info) for tests.

To execute all of the test specs, run the following command at the root of the project directory:

```bash
bundle exec rspec
```

Code coverage report is available within the `coverage` directory.

### Disabling new user registrations

1. Set the `DISABLE_USER_REGISTRATION` environment variable to `true`
1. Restart the `syncing-server`

## Docker setup

Docker is the quick and easy way to try out Standard Notes. We highly recommend using our official [Docker hub image](https://hub.docker.com/repository/docker/standardnotes/syncing-server).

### Standalone instance

Before you start make sure you have a `.env` file copied from the sample `.env.sample` and configured with your parameters.

If your intention is not contributing but just running the app we recommend using our official image from Docker hub like this:
```
docker run -d -p 3000:3000 --env-file=your-env-file standardnotes/syncing-server
```

Or if you want to use the `develop` branch that is in a work-in-progress state please use:
```
docker run -d -p 3000:3000 --env-file=your-env-file standardnotes/syncing-server:dev
```

You can then access the server via the Desktop application by setting the Sync Server Domain (Under Advanced Options) to `http://localhost:3000`

### Heroku

You can deploy your own Standard Notes server with one click on Heroku:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

## Raspberry Pi

You can run your own Standard Notes server on a Raspberry Pi using `docker-compose`.

**Requirements**

- A Raspberry Pi running Raspbian OS
- Docker (you can install it using the [convenience script](https://docs.docker.com/install/linux/docker-ce/debian/#install-using-the-convenience-script))

### Getting started

1. Install `libffi` and `libssl` dependencies:
	```
	sudo apt install -y libffi-dev libssl-dev
	```

1. Install `python3` and `python3-pip`:
	```
	sudo apt install -y python3 python3-pip
	```

1. Install `docker-compose`:
	```
	sudo pip3 install docker-compose
	```

1. Setup your `.env` file and run:
	```
	docker-compose -f docker-compose.yml -f docker-compose.raspberry-pi.yml up -d
	```

*Tested on a **Raspberry Pi 4 Model B***

## Contributing

For contributing we highly recommend you use our docker-compose setup that is provided in this repository.

### Docker compose setup

Use the included [docker-compose.yml](docker-compose.yml) file to build Standard Notes with `docker-compose`. Once your `.env` file has been copied and configured, simply run:

```
docker-compose up -d
```

This should load the syncing-server and MySQL database containers and run the necessary migrations. You should then be able to reach the server at `http://localhost:[EXPOSED_PORT]` . For example, if inside of my `.env` file I set "EXPOSED_PORT=7459" I could reach the syncing-server via `http://localhost:7459`

To stop the server, `cd` into this directory again and run `docker-compose down`

Your MySQL Data will be written to your local disk in the `data` folder to keep it persistent between container runs.
