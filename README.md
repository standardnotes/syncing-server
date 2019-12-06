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

Note: This standalone setup is designed for Development use only. Please use the `docker-compose` method (coming soon) for production instances.
