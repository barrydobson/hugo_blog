+++
author = "Barry Dobson"
categories = ["Identity Server", ".Net Core", "OAuth"]
date = 2018-06-07T09:09:58Z
description = ""
draft = false
image = "https://images.unsplash.com/photo-1495714096525-285e85481946?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=1080&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ&s=676e84fbf50b6594da2d771e98120c8a"
slug = "three-legged-oauth"
tags = ["Identity Server", ".Net Core", "OAuth"]
title = "Three Legged OAuth"

+++

Sometimes there is a situation where there is a client application (SPA, or native mobile app for instance), which needs to access an API (resource). Let's say that API requires that users be authenticated using an OAuth service. In this case the user (resource owner) will login with an authentication service via the client app. If successful the authentication service will issue an access token, and the client application can use this in an Authentication header to access the resource.

So far so good. This is standard behaviour of something like an Authorization Code grant type. Now let's say that the API needs to call another API, ok we should use a Client Credentials grant type. This is what we would usually use for server to server calls, as the server can be trusted so we can just use a shared secret. But what if API one needs to all API two using the resource owners claims? We could just proxy the Bearer Authorization header through and API two would be none the wiser, but this is dishonest, as we probably want to apply security policies to API two, and give API one the scopes to access certain endpoints.

We can solve this issue by using a three legged authorization flow. In this flow the user will authenticate as normal and the client application will access API one with the usual header. When API one needs to access API two, API one can take the bearer token and swap it for a new one which will identify API one correctly to API two, but will also contain the resource owners claims. This is done by using a custom grant type in Identity Server 4.

If you just want the code it's on [GitHub](https://github.com/barrydobson/ThreeLeggedOAuth)

## Setting up Identity Server 4

In order to start using this custom grant, first we need to set up some resources and clients in Identity Server 4.

### Resources

We will have two protected resources in this example. Each resource will have scopes depending on what we can do with them. For this example let's give each resource one scope.

API One will look like:

```json
{
    "name": "apione",
    "scopes" : [
        "apione-full"
    ]
}
```

API Two will look like:

```json
{
    "name": "apitwo",
    "scopes" : [
        "apitwo-readonly"
    ]
}
```

### Clients

Now we have the resources defined that we want to access, let's set up some clients. For our example we will need two.

The first will be for our native or web client application

```json
{
    "client_id": "native-client",
    "allowed_grant_types": [
        "authorization_code"
    ],
    "allowed_scopes": [
        "apione-full"
    ]
}
```

The second will be for Api One

```json
{
    "client_id": "apione",
    "allowed_grant_types": [
        "delegation"
    ],
    "allowed_scopes": [
        "apitwo-readonly"
    ],
    "client_secrects" : [
        "sdkfhsdfhsdhfshfskdhf"
    ]
}
```

From the config above we can see that there is pretty standard configuration for the native client. It's configured with an authorization code grant type, meaning the resource owner will be redirected to the authentication server login page and be prompted for their credentials, also it's only allowed to ask for the scope `apione-full`. The `apione` client on the other hand is configured to use a custom grant type. We also configure it with a secret so that it can identify itself.

### Custom Grant Type

We've configured API one to only be allowed to use a grant type of `delegate`. This is a custom grant type and we could have called it anything we liked. Because it's custom, Identity Server will not know how to process it out of the box. We need to write some code, and configure it to know what to do with this grant type. Identity Server 4 allows us to implement custom grant type handlers by implementing the `IExtensionGrantValidator` interface. An example of what our `delegate` grant type handler might look like this:

```csharp
public class DelegationGrantValidator : IExtensionGrantValidator
{
    private readonly ITokenValidator _validator;

    public DelegationGrantValidator(ITokenValidator validator)
    {
        _validator = validator;
    }

    public string GrantType => "delegation";

    public async Task ValidateAsync(ExtensionGrantValidationContext context)
    {
        var userToken = context.Request.Raw.Get("token");

        if (string.IsNullOrEmpty(userToken))
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        var result = await _validator.ValidateAccessTokenAsync(userToken);
        if (result.IsError)
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        var sub = result.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;

        if (string.IsNullOrEmpty(sub))
        {
            context.Result = new GrantValidationResult(TokenRequestErrors.InvalidGrant);
            return;
        }

        context.Result = new GrantValidationResult(sub, "delegation");
    }
}
```

This example is taken from the [docs](https://identityserver4.readthedocs.io/en/release/topics/extension_grants.html).

Here we can see that we will read the value of `token` from the request payload, and pass that into the validator. This value is given to us by whatever code will be calling the authentication server, and is expected to be the resource owners access token. It's passed into the validation function and provided it's valid the code will then read the `sub` claim out of it and return a new validation result for that subject. In this case the `sub` will be the resource owner.

### Calling API Two

In order for API One to authenticate and receive it's own access token for API Two, it will need to call the authentication server with the resource owners access token. The code looks something like this:

```csharp
public async Task<TokenResponse> DelegateAsync()
{
    var userToken = Request.Headers["Authorization"][0].Substring("Bearer ".Length);
    var payload = new
    {
        token = userToken
    };

    var discoClient = new DiscoveryClient("https://authentication.example.com");
    var disco = await discoClient.GetAsync();

    // create token client
    var client = new TokenClient(disco.TokenEndpoint, "apione", "secret");

    // send custom grant to token endpoint, return response
    return await client.RequestCustomGrantAsync("delegation", "apitwo-readonly", payload);
}
```

This example is based on code taken from the [docs](https://identityserver4.readthedocs.io/en/release/topics/extension_grants.html).

In this method we get the resource owners token from the Bearer token in the Authorization header, and add it to the payload we send to the authentication server to get the API one access token. The token client is created with the client ID and secret for the `apione` client, we then hit the token endpoint of the authentication server with the payload, along with the grant type (`delegation`) and the scopes we need (`apitwo-readonly`).

If authentication is successful then the response will be a `TokenResponse` object, and we use the value in the `AccessToken` property to set the Authorization header for requests to API Two.

What does this all look like? let's look at the contents of both the access tokens. 

First the resource owners access token:

```json
[
    {
        "type": "aud",
        "value": "apione"
    },
    {
        "type": "client_id",
        "value": "apione-client"
    },
    {
        "type": "sub",
        "value": "2e4b6ea5-85bc-4e53-a252-fecb163128dd"
    },
    {
        "type": "scope",
        "value": "apione-full"
    },
    {
        "type": "amr",
        "value": "pwd"
    }
]
```

Here we can see some of the claims in the access token issued to the resource owner when they authenticated in the native application. We can see the client ID, audience, subject, and allowed scopes. We can also see the authentication method (amr) was password.

Now let's look at the access token which API One got in order to access API Two on behalf of the resource owner:

```json
[
    {
        "type": "aud",
        "value": "apitwo"
    },
    {
        "type": "client_id",
        "value": "apione"
    },
    {
        "type": "sub",
        "value": "2e4b6ea5-85bc-4e53-a252-fecb163128dd"
    },
    {
        "type": "scope",
        "value": "apitwo-readonly"
    },
    {
        "type": "amr",
        "value": "delegation"
    }
]
```

We can now see that the token is identifying as API One (client_id), it has the correct scope in order to carry out the required requests, the subject is still identifying as the resource owner, and we can see the authentication method is delegation.

### Summary

By looking at the example access tokens above we can see that this method is far more honest. When API One is making requests to API Two on behalf of the resource owner, the access token now identifies the request correctly as being from API One, and the scope is validated and set correctly. This allows us to implement the correct security policies in both the API's, and the native client application doesn't need to worry about knowing anything about API Two.

A working example of the client, API one, and API two can be found in the [repo](https://github.com/barrydobson/ThreeLeggedOAuth).

