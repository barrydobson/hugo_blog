+++
author = "Barry Dobson"
categories = ["Docker", "Azure", "Hugo"]
date = 2019-03-27T14:00:58Z
description = ""
draft = false
cover = "/img/hugo-logo-wide.jpg"
slug = "static-hugo-blog-azure-cdn-2"
tags = ["Docker", "Azure", "Hugo"]
title = "Hosting a Blog with CDN in Azure - Part 2"
+++

Since Azure added the ability to host static web sites in blob storage without the need for redirect rules, I've been wanting to try it out. I use this blog as a testing ground for various bits of technology that I want to learn, whether that's writing the code, or building the infrastructure. This is how I went about building the site, setting up Azure, and how I deploy it automatically using Azure DevOps.

In this part I'll look at hosting it as a static site in Azure with a CDN, and automating the deployment.
<!--more-->

If you missed the first part take a look [here]({{< ref "static-blog-hosting.md" >}}). It explains how I am generating the site ready for hosting.

# Blob storage in Azure

The next thing I needed to do was to set up some storage in Azure. Using the portal I just created a new storage account, using general purpose v2 storage. This is important as that's the storage that supports hosting the static site.

Next I enabled Static Site Hosting on the storage account. Again, in the portal, under settings in the storage account, select static website, and enable it. You just need to fill in a couple of bits of data here.

The index page, which in this case is simply `index.html` and the error page, which depending on your Hugo template is usually `404.html`. Adjust for any paths accordingly.

Once it's finished enabling, you should see one blob container created called `$web`. This is where we need to deploy the site to.

Once that's done you can use the Azure Visual Studio Code plugin to deploy the public folder to the `$web` blob, then hit the primary endpoint from the static site configuration screen to test it out.

# Adding a CDN

Azure makes it pretty straightforward to a add CDN profile to the static site. By doing this we should really improve the performance of the site for users all over the world.

In the Azure portal the first thing I needed to do was to set up a new CDN profile. I used the Premium Verizon sku as this lets us configure rules which I needed to help with redirecting for old links and for redirecting HTTP to HTTPS.

Once I had the profile running I needed to add at least one endpoint.

I found an issue when setting up an endpoint, I found I had to set it as a custom origin type, and use the URL from the static website in the storage account.

At this point I had a URL something.azureedge.net that I could hit, and see my site being served from the CDN!

I wanted to use my own domain name, so under the endpoint blade in Azure portal, I added a new custom domain for my own domain.

At this point I headed over to my domain registrar and added the appropriate CNAME records for the domain DNS. In my case I added a CNAME record for www and blog pointing to the something.azureedge.net address.

I wanted my site to be available via HTTPS, so back in the endpoint configuration in Azure where I added my custom domain names, I selected to active HTTPS. This is an automated process that can take a couple of days to complete. The great thing is that Azure manages the certificate and there is no additional charge.

Now my site is available on the CDN, with my own domain name, with HTTPS.

# Automating the build

We could just use the command line or VS Code to deploy the site all the time, but I wanted to try out Azure DevOps, so I opted to automate the deployment when I pushed to GitHub. It turns out it's pretty easy, with just a couple of build steps.

First I created a new build pipeline and set-up my GitHub repository as a trigger.

As always, someone has been here before and this time they have created a pipeline plug-in for building Hugo. You can get the extension from the [marketplace](https://marketplace.visualstudio.com/items?itemName=giuliovdev.hugo-extension)

Once you've installed it in your DevOps organisation, just add it as the first step in a build pipeline, filling in the details as per the documentation.

The next thing we need to do is publish the public folder as a build artifact to be able to pick it up in the release pipeline.

This is done by adding the Publish Build Artifact stage. The path to publish should be `$(Build.ArtifactStagingDirectory)`.

Now the build should be able to run, and we should see our artifacts being published.

# Automating deployment

Now I have the artefacts, I need to get them into my Azure blob storage. In Azure DevOps this is done in a new release pipeline.

Set up the release pipeline to get the artefact from the build pipeline. then we need to add some jobs to run on the agent.

For these steps I chose to use the Azure CLI steps and add some inline script. The first step is to remove the old files from the blob store.

```bash
az storage blob delete-batch --source $(containerName) --account-name $(storageAccount) --output table
```

Next I need to upload the new files to storage.

```bash
az storage blob upload-batch --source $(artifactName) --destination $(containerName) --account-name $(storageAccount) --output table --no-progress
```

Lastly I want to purge the edge nodes of the CDN to ensure my new content is available straight away. This step could take a bit of time, depending on your CDN choice.

```bash
az cdn endpoint purge -g <resource-group> -n <cdn endpoint name> --profile-name <cdn profile name> --content-paths "/*"
```

Now I can run the release pipeline and should be able to see a successful release.

Make sure to set up the continuous deployment trigger on the artefact stage to allow the release to happen automatically each time there is a successful build, otherwise you will need to manually trigger a release each time.

# Cost and performance

While it's still early days (3 weeks at time of writing) since I made the change, the cost analysis in Azure tells me that in those 3 weeks I've spend 4 pence so I'm on course to come in way cheaper than my Digital Ocean droplet. Nice. Azure DevOps is on the free tier so has cost nothing.

Performance wise the audit in Chrome tells me the following:

![performance](/img/static-site-audit.png)