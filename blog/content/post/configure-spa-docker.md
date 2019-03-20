+++
author = "Barry Dobson"
categories = ["Docker", "React", "CI"]
date = 2019-03-20T09:00:58Z
description = "You have a SPA compiled as a static site, but how to you get client side configuration into it, without having to make different images for each environment?"
draft = false
cover = "/img/cog-wheels-2125183_1920.jpg"
slug = "configure-spa-docker"
tags = ["Docker", "React", "CI"]
title = "Configuring a Single Page Application in a Container"
+++

You have a SPA compiled as a static site, but how to you get client side configuration into it, without having to make different images for each environment?
<!--more-->

# The Problem

In my previous post on [developing and building a react application in Docker]({{< ref "react-docker.md" >}}) I spoke about the fact that we can use that one single container all the way from development, through CI and into production with a single build.

But there is an issue.

Given that our React application needs to talk to one or more APIs, and that our deployment pipeline has several environments, we should expect that the API address will be different for each environment we deploy to. Because the SPA is pre-compiled into a static web site, how can we get the correct configuration onto the client for each environment?

Let's take a look at how I solved the issue.

# A Solution

I did quite a bit of research into this issue, and came across a number of solutions. I've taken aspects from a couple of the ones I liked and combined them into my final solution.

## Building Configuration Files

The first thing I did is to define what configuration settings we need. I created a folder called config in the root of my repository (outside the react application) and then within that created another folder called `client-config`. I did this to highlight an important fact. **This is client side configuration. It will live on the client machine, so please don't store any secrets here**.

For each environment we have, I just create a file with the environment name, these files are JSON files so that's it's easier for applications to deal with.

```json
{
    "name": "production",
    "apiBaseUrl": "https://prod.acme.com/api"
}
```

Here is an example of a simple `production.json` file. Just a name and an API address. You can have as many settings as you need though.

It's also important to have a `local.json` file. This will be used for running the application locally. You may also choose to .gitignore that file if each developer has different configuration.

You could also choose to create these files (other than local) within your CI pipeline depending on where you like to keep your configuration. You may prefer keeping such details within CI and therefore you can just build the files at that time.

## Choosing the Correct File

Now we have a directory full of environment configuration files, how do we choose the right one? A little bit of Docker magic.

The first thing to do is change up the `production.Dockerfile`

```dockerfile
FROM node:10.15.3-alpine as build-deps

WORKDIR /usr/src/app
RUN npm install react-scripts@2.1.8 -g --silent

COPY ./react-app/package.json ./react-app/yarn.lock ./

RUN yarn
COPY ./react-app/ ./
RUN CI=true npm test
RUN yarn build

FROM nginx:1.15.9-alpine
ARG CLIENT_ENVIRONMENT=local
ENV CLIENT_ENVIRONMENT="${CLIENT_ENVIRONMENT}"

COPY ./lib/launch-prod.sh ./
RUN chmod +x launch-prod.sh
COPY config/client-side /usr/share/nginx/config/

COPY --from=build-deps /usr/src/app/build /usr/share/nginx/html
EXPOSE 80
CMD ./launch-prod.sh
```

I've made a couple of changes to this file since the last post.

Firstly I added

```dockerfile
ARG CLIENT_ENVIRONMENT=local
ENV CLIENT_ENVIRONMENT="${CLIENT_ENVIRONMENT}"
```

This creates a build argument called `CLIENT_ENVIRONMENT`. If it's not supplied by the docker build command it's defaulting to local. Then it creates an environment variable with the same name and sets that to the value of the build argument.

The next couple of lines are taking a shell script (I'll get to that soon) and copying it into the container and modifying it to be executable.

```dockerfile
COPY config/client-side /usr/share/nginx/config/
```

Now I am taking the directory of configuration files and copying those into the container. All of them. This is important.

Finally I'm changing the command executed on start up from the original Ngix to the `launch-prod.sh` shell script we copied into the container earlier.

Let's take a look at that start-up script...

```bash
cp /usr/share/nginx/config/$CLIENT_ENVIRONMENT.json /usr/share/nginx/html/config.json
nginx -g "daemon off;"
```

When the container is started it executes the above script. This is where the clever bit is.

The first line copies the configuration file with the name supplied by the environment variable `CLIENT_ENVIRONMENT` into the root of the website in Nginx. This is the same location where I copied our application files into, then we start up Nginx as before.

So now I just need to tell the container what the value of the environment variable is. The command will be...

```bash
docker run --rm -p 3001:80 -e CLIENT_ENVIRONMENT=production prod
```

Here I'm setting the variable to production, so that when the container starts up the `production.json` will be copied into the root of the site as `config.json`. Because this happens at runtime, I can use the same container across all my environments, and because we always copy the file and rename it to `config.json` the application just needs that file and doesn't need to worry about the name changing.

## Getting the Configuration in React

How do I get the config json file into my React application? It depends on your application. If you're using something like Redux to manage state, that's probably where you want to store the configuration, and you would fetch it on start up.

Using the default App.js file that is added by Create React App, the code below will also work to get the config.

```js
  constructor(props) {
    super(props);

    this.state = {
      config: {},
    };
  }

  async componentDidMount() {
    const response = await fetch('config.json');
    const config = await response.json();
    return this.setState({ config });
  }
```

Now I can access things like `config.name` from my component.

## What about the development container

This is great for our production container, but what about running locally using the development container? I make an additional volume mount in the docker compose file.

```yaml
dev:
    container_name: react-app-dev
    build:
      context: .
      dockerfile: local.Dockerfile
    volumes:
      - './config/client-side/local.json:/usr/src/app/public/config.json'
      - './react-app:/usr/src/app'
      - '/usr/src/app/node_modules'
    ports:
      - '3000:3000'
    environment:
      - NODE_ENV=development
```

The additional volume takes the `local.json` file and mounts it as `config.json` in the root of the application. This means that the code will work as expected.