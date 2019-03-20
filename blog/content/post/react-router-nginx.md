+++
author = "Barry Dobson"
categories = ["Docker", "React", "Nginx"]
date = 2019-03-20T12:00:58Z
description = "This is a quick note on configuring Nginx to correctly proxy requests when using React router."
draft = false
cover = "/img/jens-johnsson-415903-unsplash.jpg"
slug = "react-router-nginx"
tags = ["Docker", "React", "Nginx"]
title = "Configuring Nginx for React Router"
+++

This is a quick note on configuring Nginx to correctly proxy requests when using React router.
<!--more-->

In the last couple of posts I've written about hosting a static SPA in an Nginx Docker container. If you are using React router, there is some additional config that you need to add to make it work when a user bookmarks a route or refreshes a page on a given route.

```nginx
server {
  listen       80;
  location / {
    root   /usr/share/nginx/html;
    index  index.html index.htm;
    try_files $uri $uri/ /index.html =404;
  }
}
```

This is a sample Nginx config that will work. The important line is the `try_files` entry.

In order to add this into the Nginx container add the following line to the Dockerfile:

```dockerfile
COPY ./config/nginx/nginx.conf /etc/nginx/conf.d/default.conf
```

This will then be picked up when the container starts.