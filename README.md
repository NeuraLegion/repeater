# Intro

**Repeater** allows you to run NexPloit scans without exposing your ports outside. Also, it can be useful, if you want to run a local scan without deploying.

By design, repeater is just a docker image with a utility, that keeps connection with amq.nexploit.app:5672, performs requests on local target and sends responses to NexPloit backend.

## How to run a sample

To run an example, you need Docker Compose. It's a tool for defining and running multi-container Docker applications. You can download it from [official Docker page](https://docs.docker.com/compose/install/).

Create a `docker-compose.yml` file with the following content.

```yml
version: '3'
services:
  juiceshop.local:
    image: bkimminich/juice-shop
  repeater:
    image: neuralegion/repeater:latest
    restart: always
    environment:
      AGENT_KEY: g5f1clg.lkfcjgnyyuzp34a1fnzmxn8lrxcjuwgu
      AGENT_ID: cdf07782-bc6c-486a-b459-e182808faa33
```

Here [juice shop](https://owasp.org/www-project-juice-shop/) is a dedicated image to suffer from attacks. The image runs the app on 3000 port.

You can run this configuration with ```docker-compose up```. It'll throw an error, like

>repeater_1 | Unhandled exception in spawn: 403 - ACCESS_REFUSED - Login was refused using authentication mechanism PLAIN. For details see the broker logfile. (AMQP::Client::Connection::ClosedException)

because you have invalid `AGENT_ID` and `AGENT_KEY`. Go to `https://nexploit.app/agent`, add a new agent and copy its UUID. Put it to your `docker-compose.yml` file as `AGENT_ID`.

Now we need to set up a proper API key for our agent. For this, go to `https://nexploit.app/profile` and find *Manage your application API keys* section. Add a new key via *Create new API key* button. Choose *agents:write:repeater* scope if you want to use it just like a local request producer.

![](https://i.imgur.com/5LYzv4lm.png)

Copy a key and put it as `AGENT_KEY` to `docker-compose.yml`. Run ```docker-compose up``` once again. Now we can run a scan. Go to the https://nexploit.app/scans and push *New Scan*.

![](https://i.imgur.com/GnL8Atim.png)

Fill *Scan Name* field, select *Crawler* type as discovery type. Set `http://juiceshop.local:3000` as a target. Then go to *Additional Settings* and select your agent in *Agents* field. Press *Run* and get ready to see security issues.

## Extra Options

### Extra Headers

Repeater allows the user to overload extra headers into the repeater's request without setting them up in NexPloit
This is done by setting the EXTRA_HEADERS environment variable.
example of usage:

```yml
version: '3'
services:
  repeater:
    image: neuralegion/repeater:latest
    restart: always
    environment:
      AGENT_KEY: g5f1clg.lkfcjgnyyuzp34a1fnzmxn8lrxcjuwgu
      AGENT_ID: cdf07782-bc6c-486a-b459-e182808faa33
      EXTRA_HEADERS: {"my_header": "special token"}
```

or as a command line configuration like

```bash
docker run neuralegion/repeater -e 'EXTRA_HEADERS={"my_header": "special token"}'
```

## Contributing

1. Fork it (<https://github.com/NeuraLegion/repeater/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Bar Hofesh](https://github.com/bararchy) - creator and maintainer
