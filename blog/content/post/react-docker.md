+++
author = "Barry Dobson"
categories = ["Docker", "React", "CI"]
date = 2019-03-19T20:00:58Z
description = ""
draft = false
cover = ""
slug = "react-docker"
tags = ["Docker", "React", "CI"]
title = "Building and Testing React Applications with Docker"
+++

I recently had a need to introduce a team at work to developing and building on containers for an application that they are starting to build. The end goal is that the applicaiton, a React SPA with a .Net Core API will be built in containers, then run through a Jenkins pipeline, ultimately ending up being deployed in Kubernetes. It's been an interesting distraction, so much so that I decided to put together a [starter repository](https://github.com/barrydobson/react-docker-base) and this post. In this post I'll describe how I suggested they tackle the React application with unit testing. In the next couple of posts I'll describe the .Net Core API and then how we can run integration testing in docker within the pipeline.

Being able to build and deploy applications in containers is becoming more and more important, as people switch to hosting applications in the cloud on services such as Kubernetes or other container services. One of the big benefits of deploying to production in contianers is that developers can run the very same container locally, that will be shipped to production. This is also true for any QA environments, and CI pipelines, we can build a continer once, test it, and then deploy the same code to production.

When working on a web application that's built on a framework such as React, it's also important for development to be able to see changes quickly, whilst editing the codebase using features like hot reloading for example, and to be able to run any tests such as unit or integration tests.

Using Docker it's possible to cover all three senarios with a couple of docker files, and a docker compose script. Developers can spin up a container to serve a development site, with hot reloading, run unit tests, and run any integration or end to end tests. Then when the code is push up to VCS the CI server can pick up the same compose file, run the tests, and produce a production ready build of the applicaiton, and build a lightweight container ready to be released into production.

Lets take a look at how this done.

## Building the Development Environment

The first thing we need to look at it how do we set up the develpoment environment. We have a few goals.

+ We run the applicaiton in a container
+ We need hot reloading when a change is made on the host machine
+ We need to be able to run unit tests

Let's start by thinking about getting the application running in a container. Assuming we scaffolded the application using [Create-React-App](https://github.com/facebook/create-react-app), we'll be running a nodejs server, so that seems a good place to start with our dockerfile. 

First let's create a new file called local.Dockerfile (the name will become clear later).

```dockerfile
FROM node:10.15.3-alpine

RUN npm install react-scripts@2.1.8 -g --silent

WORKDIR /usr/src/app

ENV PATH /usr/src/app/node_modules/.bin:$PATH

COPY ./react-app/package.json ./react-app/yarn.lock ./

RUN yarn install

CMD npm start
```

What have we got here? We're using the current (at time of writing) LTS version of the official node image. Next we install some react-scripts, set up our working directory, add our node_modules to the path environment variable, copy in our package.json file, and run yarn install.

Why do we only copy our package.json file, and not our whole application? Two reasons. Firstly, this is good practice to make use of dockers layer caching, meaning we only need to install our modules if we change the package.json file, secondly it's do with our requirement of hot reloading.

Finally we tell the container to run `npm start`. Because this is a `CMD` command, this will execute when the container is run, not built, which is lucky, because there is no code in the container right now.

So how to we get the code from our host machine, into the container whilst still be able to edit it? Let's create a docker-compose file to help us do this.

```yaml
version: '3.5'

services:
  dev:
    container_name: react-app-dev
    build:
      context: .
      dockerfile: local.Dockerfile
    volumes:
      - './react-app:/usr/src/app'
      - '/usr/src/app/node_modules'
    ports:
      - '3000:3000'
    environment:
      - NODE_ENV=development
```

We've defined a single service called 'dev'. We specify a container name, so we can keep track of it, and some build details. We point at the local.Dockerfile we just created, and publish port 3000 to the host port 3000 so we can hit the site. We also set the `NODE_ENV` environment variable so our code is run with debugging goodness.

The important part of the compose file is the volumes. We first tell Docker to mount our `react-app` directory into the container as `/usr/src/app`. Then we tell Docker to create us a volume for node modules to live in, this means when we mount the application directory, the node_modules in the container will be preserved. This means that node_modules required by the application won't be present on our host machine, and only in the container.

So now we can start the container and check everything works as expected.

```sh
docker-compose build dev
docker-compose up dev
```

First we build the image, then we run it. If all is well you should see some out from the container to tell us it's running...

```bash
react-app-dev |
react-app-dev | > src@0.1.0 start /usr/src/app
react-app-dev | > react-scripts start
react-app-dev |
react-app-dev | Starting the development server...
react-app-dev |
react-app-dev | Compiled successfully!
react-app-dev |
react-app-dev | You can now view src in the browser.
react-app-dev |
react-app-dev |   Local:            http://localhost:3000/
react-app-dev |   On Your Network:  http://172.18.0.2:3000/
react-app-dev |
react-app-dev | Note that the development build is not optimized.
react-app-dev | To create a production build, use yarn build.
react-app-dev |
```