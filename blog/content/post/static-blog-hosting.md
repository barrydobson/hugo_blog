+++
author = "Barry Dobson"
categories = ["Docker", "Azure", "Hugo"]
date = 2019-03-27T11:00:58Z
description = ""
draft = false
cover = "/img/hugo-logo-wide.jpg"
slug = "static-hugo-blog-azure-cdn-1"
tags = ["Docker", "Azure", "Hugo"]
title = "Hosting a Blog with CDN in Azure - Part 1"
+++

Since Azure added the ability to host static web sites in blob storage without the need for redirect rules, I've been wanting to try it out. I use this blog as a testing ground for various bits of technology that I want to learn, whether that's writing the code, or building the infrastructure. This is how I went about building the site, setting up Azure, and how I deploy it automatically using Azure DevOps.

In this first article I'll look at setting up a new blog, migrating my existing data into it, and building the files required for hosting.
<!--more-->

# Choosing a blogging platform

The first challenge was choosing a platform to generate my static content. I was hosting my site on [Ghost](https://ghost.org/) hosted in [Digital Ocean](https://www.digitalocean.com/), and it was good, although it was costing $5 a month. But in order to get static content from that I'd need to do a lot more work. There is a great post about how to achieve that by [Steve Elliott](https://www.tegud.net/ghost-gatsby/).

I wanted something simple to get going, so I opted for [Hugo](https://gohugo.io/). It's not just a blogging platform, you can generate a variety of different types of sites. It has a command line interface for building and running the site, a large number of community made themes for getting started, and content is written in markdown. This seemed like a good place to start.

# Running Hugo locally

Now I have my platform of choice, it's time to set up the structure locally and spin it up. Like I mentioned above, Hugo has a command line interface tool that does all the heavy lifting.

I don't really want to install hugo on my own machine, so it's Docker time.

```dockerfile
FROM alpine:latest
RUN apk --no-cache add ca-certificates curl bash
RUN curl -L https://github.com/gohugoio/hugo/releases/download/v0.54.0/hugo_0.54.0_Linux-64bit.tar.gz | tar -zOxf - hugo > /usr/bin/hugo && chmod +x /usr/bin/hugo
WORKDIR /app
ENTRYPOINT ["bash"]
```

Next a docker-compose file for added convenience...

```yaml
services:
  hugo:
    container_name: hugo-cli
    build:
      context: .
      dockerfile: Dockerfile
    image: hugo:0.54.0
    volumes:
      - './:/app'
    working_dir: '/app/my-site'
    ports:
      - '1313:1313'
```

Get it built and set up a new site...

```bash
docker-compose build hugo
docker-compose run --rm --service-ports --entrypoint "hugo new site my-site" hugo
```

If all goes well, on our machine we should have a new subdirectory called `my-site` and within that, should be a brand new Hugo site.

Let's run it in a local server...

```bash
docker-compose run --rm --service-ports --entrypoint "hugo server -D --enableGitInfo --bind \"0.0.0.0\"" hugo
```

Now browsing to `localhost:1313` we should see the site running. The local server will also hot reload, so any changes made are instantly reflected in the browser.

Make changes to the config.toml file and themes as per the documentation.

# Getting content from Ghost

The first thing I had to do was get my existing content out of my existing Ghost blog. Luckily the Ghost platform makes it easy to get your content in the form of Json. Once I had this I needed to take the posts and somehow convert them into Markdown.

Fortunately someone already created a tool to do it on [GitHub](https://github.com/jbarone/ghostToHugo). All that was needed was a quick Dockerfile to run it on.

```dockerfile
FROM alpine:latest
RUN apk --no-cache add ca-certificates curl bash
RUN curl -L https://github.com/jbarone/ghostToHugo/releases/download/v0.3.0/ghostToHugo_0.3.0_Linux_x86_64.tar.gz | tar -zOxf - ghostToHugo > /usr/bin/ghostToHugo && chmod +x /usr/bin/ghostToHugo
ENTRYPOINT ["bash"]
```

Then build and run...

```bash
docker build -t ghostmigrate .
docker run --rm -v `pwd`:/pwd/ -p 1313:1313/tcp -it -w '/pwd/Ghost' ghostmigrate
```

Assuming that our exported Ghost Json file is located in a sub folder of the current directory called `Ghost` then we just need to run...

```bash
ghostToHugo export.json -l <Path To Hugo>`
```

This should take all the pages and posts from Ghost and create the Markdown required to work in Hugo. It's worth checking the front matter and content to make sure it's formatted as you want.

# Creating a static site

When I was happy with the content locally the next step was to build the site ready for deployment.

Using the same Docker image as I used previously...

```bash
docker-compose run --rm --entrypoint "hugo --enableGitInfo" hugo
```

This should generate a public folder in the `my-site` folder which will contain all the static files required to run the site.

# Next steps

In my next post, we'll take a look at hosting this in Azure blob storage and accessing it via the static website functionality.