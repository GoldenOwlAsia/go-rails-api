# Golden Owl Solutions Rails API Boilerplate

A boilerplate for quickly setting up a Rails API:

- Ruby (3.4.12)
- Rails (8.1.4)
- PostgreSQL
- Sidekiq, Redis
- Devise, Devise JWT
- Swagger
- Sentry
- RSpec

## Getting Started

Follow these steps to install and start the application:

- Install ruby `3.4.12`
```bash
rbenv install 3.4.12
rbenv local 3.4.12
ruby -v
```
- Install gems:
```bash
gem install bundler
bundle install
```
- Add `config/database.yml` file (reference: `config/database.yml.sample`)
- Add `.env` file (reference: `.env.sample`)
- Generate new rails master key
```bash
rm -f config/credentials.yml.enc && rm -f config/master.key && EDITOR=vim bin/rails credentials:edit
```
- Database setup:
```bash
bin/rails db:setup
```
- Start server:
```bash
bin/rails s
bundle exec sidekiq
```

**Specs**

```bash
bundle exec rspec
```

Check the coverage at `coverage/index.html`

**API Doc**

```bash
bin/rake rswag
```

Check the generated document at `http://localhost:3000/docs`

**Security Vulnerability Scanner**

```bash
bundle exec brakeman
```

**Linter With Rubocop**

```bash
bundle exec rubocop
```

## License

Licensed under the MIT license, see the separate [LICENSE.md](./LICENSE.md) file.
