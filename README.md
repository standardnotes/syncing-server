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

2. Create a .env file in the project's root directory. Add environment variables (see Environment variables for full listing):

	```
	DB_HOST=localhost
	...
	```

3. Initialize project:

	```
	bundle install
	rails db:create db:migrate
	```

4. Start the server:

	```
	rails s
	```

### Environment variables

**SECRET_KEY_BASE**

Rails secret key used only in production environment

**RAILS_ENV**

Rails environment, set it to `production` on production server.

**DB_HOST**

Database host.

**DB_PORT**

Database port. 3306 is standard.

**DB_DATABASE**

Database name.

**DB_USERNAME**

Database username.

**DB_PASSWORD**

Database password.

## License

Licensed under the GPLv3: http://www.gnu.org/licenses/gpl-3.0.html
