+++
author = "Barry Dobson"
categories = ["AWS", "Docker", "Elastic Beanstalk"]
date = 2018-05-26T13:11:12Z
description = ""
draft = false
cover = "https://images.unsplash.com/uploads/141143339879512fe9b0d/f72e2c85?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=1080&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ&s=e85af6f6e4dc5dfef2af958ae493db62"
slug = "scaling-with-elastic-beanstalk"
tags = ["AWS", "Docker", "Elastic Beanstalk"]
title = "Scaling with Elastic Beanstalk"

+++

When you’re building out a new API or service, it’s sometimes difficult to know exactly what sort of server you’re going to need to run it on. You probably have a rough idea of what your MVP is, but you don’t really know what features you will need to add in the future. 

You might not really know what sort of traffic you will be dealing with either, both in terms of number of requests or load pattern. In order to get your API live, you need to take an educated guess, and size for your estimated peak load.

I’ve recently gone through a sizing exercise for one of our new APIs. Initially we had the problems described above, so went with what we knew in terms of instance sizing, we played it safe and opted to deploy on instances which were sized to easily handle our estimated peak load. We also decided that our pre-production environments would be deployed on the same configuration so that we could get a ‘like live’ QA system whilst we initially built the application.

The problem with this is that once you get live and start slowly ramping up live traffic, you get a better idea of your traffic patterns, you also start to think about resilience. In AWS, we need to be thinking about splitting our servers across availability zones and maybe across regions too.

We saw that our servers were over-sized for our average load, and having the same specification of servers across 3 pre-production environments was costing us money that we didn’t really need to spend. Our production boxes were also all in the same availability zone, so losing that would mean no service. As well as server sizing we also had other things to consider, such as the ability to easily scale as we added more traffic to our new API. As our service was already in AWS we decided to take a look at what AWS could offer in terms of scaling solutions.

#### Elastic Beanstalk
The Amazon documentation describes Elastic Beanstalk as:
>With Elastic Beanstalk, you can quickly deploy and manage applications in the AWS Cloud without worrying about the infrastructure that runs those applications. AWS Elastic Beanstalk reduces management complexity without restricting choice or control. You simply upload your application, and Elastic Beanstalk automatically handles the details of capacity provisioning, load balancing, scaling, and application health monitoring.

Elastic Beanstalk would allow us to define an environment containing EC2 instance details, Elastic Load Balancers, EBS, Security groups, and auto scaling groups, all in a single config file. In order to change any part of the infrastructure we could just make a change to the config file, save it S3, and then apply it to an environment and by using auto scaling groups triggered by Cloud Watch alarms we could also scale the application up and down based on traffic.

#### Configuring and Creating an Environment
Setting up an application in Elastic Beanstalk is pretty straight forward. The first step is to define the application, then within an application you define environments. These are typically things like QA, UAT, and Production. Each environment can have a completely different configuration if required. Once you have an environment configured and up and running (usually with a sample application) you can go ahead and publish your own application to it and you’re done. Now it’s a case of changing the various configuration options to fine tune your environment. You may need to consider things such as instance types, VPC configurations, security groups, monitoring and auto scaling.

#### Automating Provisioning and Deployment
Being able to work with the AWS web UI is all well and good and pretty straightforward, but the aim here is automate every aspect of this process. We need to automate the creation and updating of environment configuration, EC2 instance configuration, and application deployment. 

To do this we use a combination of two command line tools. The first one being the standard AWS command line tool, and the other being the AWS EB command line tool. The EB tool is made, as the name suggests, for Elastic Beanstalk, and it will allow you carry out the main operations you need but we found it was a little restrictive in certain areas when it comes to some of the tasks you need to perform when automating your deployments, that’s where the AWS command line tool comes in.

Let’s take a look at the broad steps we need to automate to get from having nothing but an empty Elastic Beanstalk application (with no environments) to a functioning API:

* Upload a configuration file to describe an environment
* Create (or update) an environment
* Publish a specific application version to Elastic Beanstalk
* Deploy a specific application version to an environment

The way we tackled this was to create a bash script for each aspect of the process. The scripts take the various parameters they need from the command line, which can be given to it by the build automation server. The bash scripts just use a combination of the command line tools mentioned above to perform the various tasks.

One area of the AWS documentation on all this that I found to be a bit light was exactly how you can define the various configuration options for the environment. In the end we used a bit of a cheaty way to get the configuration Yaml file that we can then upload to S3 and use to define the environment. 
The EB tool has a config command, this will do a couple of things, but one of the things it lets you do is to edit the active config in a text editor. This basically exposes the format of the file, and all the options you can change. I’ve included an example below:
<script src="https://gist.github.com/barrydobson/9d357be25ac7c84a3aa9f567ba73f56a.js"></script>

Another aspect of the environment creation command to pay close attention to is the CNAME parameter. This will be used to point to the correct load balancer. As the things like EC2 instances and Elastic Load Balancers are immutable, it would be a pain to have to change the URL of your API in everything that calls it every time you make a change that swaps out the load balancer. This CNAME is the constant that holds it all together. Once you define it for the environment you are given a URL that points to you environment. Once you have this you can then point your DNS name to the Beanstalk address. The whole thing then becomes completely transparent to consumers. 

It also allows for blue/green deploys where you can stand up a completely separate environment. Lets say your current live traffic is using an environment called 'green'. You could choose to create a new environment, which is exactly the same as 'green' but called 'blue'. You could then deploy a new version of the application to 'blue', test it against the Beanstalk URL, then once you are happy it’s working, you can perform a swap using the EB tool to the 'green' environment. This will swap the CNAME records of the two environments, meaning your live traffic is now going to the 'blue' environment. This may be useful if you want to deploy your application without ever taking any instances out of the load balancer.

#### What’s next?
We are using Elastic Beanstalk for one of our API’s in production now, and are still making slight changes to our auto scaling configurations as we start to ramp up traffic to it. We can monitor the metrics in Cloud Watch, and change the scaling parameters as we go, using our build pipelines to push the changes out, with no impact on the live traffic.
We are also starting to build a new worker service that will also use Elastic Beanstalk, but will scale based on a custom trigger which should give us significant performance improvements over our existing versions.

This article was originally published [here](https://engineering.laterooms.com/scaling-with-elastic-beanstalk/)

