# Standard Notes Syncing Server

### Running your own server
You can run your own Standard Notes server and use it with any Standard Notes app. This allows you to have 100% control of your data. This server is built with Ruby on Rails and can be deployed in minutes.

#### Getting started

**Requirements**

- Ruby 2.3+
- Rails 5
- MySQL 5.6+ database

**Instructions**

1. Clone the project:

	```
	git clone https://github.com/standardnotes/syncing-server.git
	```

2. Create a .env file in the project's root directory. See env.sample for required values.


3. Initialize project:

	```
	bundle install
	rails db:create db:migrate
	```

4. Start the server:

	```
	rails s
	```

### Docker Setup

Docker is the quick and easy way to try out Standard Notes. With two commands you'll be up and running.

#### Standalone Instance

The `Dockerfile` is enough to get you up and running. Once Docker is installed on your system simply run the following commands to get up and running in Development Mode.

```
$ docker build -t syncing-server .
$ docker run -d \
  -p 3000:3000 \
  --name my-syncing-server \
  syncing-server
```

You can then access the server via the Desktop application by setting the Sync Server Domain (Under Advanced Options) to `http://localhost:3000`

Note: This standalone setup is designed for Development use only. Please use the `docker-compose` method for production instances.

#### Docker Compose

Use the included `docker-compose.yml` file to build Standard Notes with docker-compose. Once your `.env` file has been copied and configured, simply run:

```
docker-compose up -d
```

This should load the syncing-server and MySQL database containers and run the necessary migrations. You should then be able to reach the server at `http://localhost:[EXPOSED_PORT]` . For example, if inside of my `.env` file I set "EXPOSED_PORT=7459" I could reach the syncing-server via `http://localhost:7459`

To stop the server, `cd` into this directory again and run `docker-compose down`

Your MySQL Data will be written to your local disk at `/var/lib/mysql` - Be sure to back this up in a production instance.

### Heroku

You can deploy your own Standard Notes server with one click on Heroku:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)