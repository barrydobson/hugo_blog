+++
author = "Barry Dobson"
categories = ["Docker", "React", "CI"]
date = 2019-03-19T17:00:58Z
description = ""
draft = false
cover = "https://images.unsplash.com/photo-1533234427049-9e9bb093186d?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=1080&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ&s=676e84fbf50b6594da2d771e98120c8a"
slug = "react-docker"
tags = ["Docker", "React", "CI"]
title = "Building and Testing React Applications with Docker"
+++

I recently had a need to introduce a team at work to developing and building on containers for an application that they are starting to build. The end goal is that the application, a React SPA with a .Net Core API will be built in containers, then run through a Jenkins pipeline, ultimately ending up being deployed in Kubernetes. It's been an interesting distraction, so much so that I decided to put together a [starter repository](https://github.com/barrydobson/react-docker-base) and this post. In this post I'll describe how I suggested they tackle the React application with unit testing. In the next couple of posts I'll describe the .Net Core API and then how we can run integration testing in docker within the pipeline.

Being able to build and deploy applications in containers is becoming more and more important, as people switch to hosting applications in the cloud on services such as Kubernetes or other container services. One of the big benefits of deploying to production in containers is that developers can run the very same container locally, that will be shipped to production. This is also true for any QA environments, and CI pipelines, we can build a container once, test it, and then deploy the same code to production.

When working on a web application that's built on a framework such as React, it's also important for development to be able to see changes quickly, whilst editing the codebase using features like hot reloading for example, and to be able to run any tests such as unit or integration tests.

Using Docker it's possible to cover all three scenarios with a couple of docker files, and a docker compose script. Developers can spin up a container to serve a development site, with hot reloading, run unit tests, and run any integration or end to end tests. Then when the code is push up to VCS the CI server can pick up the same compose file, run the tests, and produce a production ready build of the application, and build a lightweight container ready to be released into production.

Lets take a look at how this done.

## Building the Development Environment

The first thing we need to look at it how do we set up the development environment. We have a few goals.

+ We run the application in a container
+ We need hot reloading when a change is made on the host machine
+ We need to be able to run unit tests

Let's start by thinking about getting the application running in a container. Assuming we built the application using [Create-React-App](https://github.com/facebook/create-react-app), we'll be running a nodejs server, so that seems a good place to start with our dockerfile.

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

```bash
docker-compose build dev
docker-compose up dev
```

First we build the image, then we run it. If all is well you should see some output from the container to tell us it's running...

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

Browsing to the localhost url should show the application running!

Let's make sure the hot reload functionality is running. Leaving the container running, change a part of the application, perhaps some text on a component. When you save the changes, and check back in the browser then you should find the changes reflected.

So we've managed to accomplish two of the three objectives.

The last one was to be able to run tests. Since we are using the bundled Jest test runner that comes from Create React Application, there are two ways we can do this. By default running `npm test` will start Jest in watcher mode. This means that it will look for changes as you make changes to the application, and automatically run the tests. This would be fine for local development and we can do that in our container, but perhaps more useful and reusable is to run them in CI mode. Let's edit our docker compose file and add a new service, in addition to the dev service we already have.

```yaml
test:
    container_name: react-app-test
    build:
      context: .
      dockerfile: local.Dockerfile
    volumes:
      - './react-app:/usr/src/app'
      - '/usr/src/app/node_modules'
    environment:
      - CI=true
    command: npm test
```

This service is using the same Dockerfile we used for our development server, but there are a couple of important differences.

The first is the environment variables. We are setting an environment variable called `CI` to true. This tells Jest that it should just execute the tests once, and exit. Next we override the `npm start` command with `npm test`. This means that when the container is started, it will execute the tests and finish.

Let's try it out.

```bash
docker-compose build test
docker-compose run --rm test
```

Executing the above should build the test image and execute the tests. If everything worked, and the tests are passing we should see some output in the console.

```bash
> src@0.1.0 test /usr/src/app
> react-scripts test

PASS src/App.test.js
  ✓ renders without crashing (131ms)

Test Suites: 1 passed, 1 total
Tests:       1 passed, 1 total
Snapshots:   0 total
Time:        3.882s
Ran all test suites.

```

Great. Now we can develop and run our unit tests locally, all in a container.

## Building the Application for Production

So we've managed to develop and test our application locally in containers, now what about building a container that we can deploy? When we build a React application, Web Pack builds a set of static minified files, that we can serve from a basic web server, we really don't need nodejs at this point.

Create a new file called `production.Dockerfile`

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
COPY --from=build-deps /usr/src/app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

This Dockerfile makes use of the multistage build in Docker. Here we use a node base image, copy in the package.json as we did for the development version, and run yarn to pull all our packages. This time we copy our code into the container and run our unit tests. Any failing tests here will fail the Docker build and cause a CI pipeline to fail. If the testing is successful we run `yarn build`. This will compile the application into a production build.

Next we are using the official Nginx image to serve our site from. We copy the build output from the first image into the Nginx image in the html folder so we can serve it out. We then instruct the image to expose port 80 and run Nginx.

Next we need to add a third service to our docker-compose file. This time to build and run the production container.

```yaml
prod:
    container_name: react-app-prod
    build:
      context: .
      dockerfile: production.Dockerfile
    ports:
      - '3001:80'
    environment:
      - NODE_ENV=production
```

Here we can see that this time the `prod` service is using the production Dockerfile we just created, we map port 80 onto port 3001 of the host, and set the `NODE_ENV` environment variable.

Running the following commands will build and start the container.

```bash
docker-compose build prod
docker-compose up prod
```

Now if we browse to localhost port 3001 we should see our application running. This time in production mode, with all the scripts correctly packed by Web Pack.

## So how do we use in CI

For a CI pipeline to work with what we have just seen it's basically the same commands. A pipeline would typically look like this:

+ Pull from VCS repository
+ Use the production.Dockerfile to run tests, and build the production image
+ Push the image to a container registry to make it available for deployment.

Pretty straight forward.