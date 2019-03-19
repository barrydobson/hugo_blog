+++
author = "Barry Dobson"
categories = ["Docker", ".Net Core"]
date = 2018-06-04T10:15:20Z
description = ""
draft = false
cover = "https://images.unsplash.com/photo-1494961104209-3c223057bd26?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=1080&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ&s=76db2d0c70f6b06cc35f2b569f1a9efa"
slug = "build-and-run-aspnet-core-docker"
tags = ["Docker", ".Net Core"]
title = "Build and Run ASP.Net Core Application in Docker"

+++

Building and running a ASP.Net Core web application in a Docker container is pretty straight forward. We can use use the images provided by Microsoft. There is one image for building, and one for running. We can also use Dockers new multi stage build feature to make things even easier.

Let’s take a look at a Dockerfile.

```dockerfile
FROM microsoft/aspnetcore-build:2 As build
WORKDIR /app
COPY ./app/WebApp.csproj .
RUN ["dotnet", "restore"]
COPY ./src .
RUN dotnet publish -c Release -o ./output

FROM microsoft/aspnetcore:2
WORKDIR /app
COPY --from=build /app/output .
ENTRYPOINT ["dotnet", "WebApp.dll"]
```

Breaking the file down it works as follows:
* We use the base image from DockerHub. The ‘build’ bit means it’s been made with the SDK and contains all the bits we need to compile our application. The ‘As build’ part is the multi stage build feature, being able to assign a name to the stage.
* We set a working directory within the container and copy our project file into the container.
* We now run a NuGet restore using the dotnet command line. This will read the project the file we copied and pull down any dependencies
* Now we copy over the rest of the files and use the dotnet command line to build and publish to the output directory. We could also run our tests here.
* Now we pull down a different image from DockerHub. This time it’s a more lightweight image which just contains a runtime environment.
* We again set the work directory, and now we copy the application we compiled in the previous stage, from the output directory (where we published to) into the runtime container.
* Finally we set an entrypoint which will be the dotnet cli, running the assembly we compiled.

In the build step you notice we have seperate restore and publish commands. Why do we restore then build, when building will also perform a restore? Well the reason is so the Docker can cache layers with the packages when there are no changes, to help speed up subsequent builds. For more information about how Docker will cache layers see the [docs](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

Now we have our Docker file in the root of the application, we can now build the image:

`docker build -t WebApp .`

If it’s the first time you have used the base images, Docker will pull them down which may take some time, depending on your connection speed. The next time you build, the images will be cached locally, so will be much quicker.

Now run a container:

`docker run -it --rm -p 8080:80 WebApp`

If all is good you should now be browse to [http://localhost:8080](http://localhost:8080) and see your site.

