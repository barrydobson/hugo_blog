+++
author = "Barry Dobson"
categories = ["VB", "Archives"]
date = 2008-06-13T08:28:00Z
description = ""
draft = false
cover = "https://images.unsplash.com/photo-1470173274384-c4e8e2f9ea4c?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=1080&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ&s=7779b521f2047d20269300fc192bd19e"
slug = "working-with-ldap-in-vb-net"
tags = ["VB", "Archives"]
title = "Working with LDAP in VB.Net"
aliases = [
    "/2008/06/13/working-with-ldap-in-vbnet/"
]
+++

I wrote a post a while ago dealing with an error that VB can throw when dealing with an LDAP connection. Because this post has proved popular with people searching for the error code on Google, I thought I’d put together a quick post on using LDAP in VB.Net.

### Simple Directory Search

To perform a simple query you can use the following syntax:

```vbnet
Dim results as SearchResultCollection

Using dir As New DirectoryEntry(connectionPath, principle, credentials, AuthenticationTypes.ServerBind)
	Dim s As New DirectorySearcher
	s.SearchRoot = dir
        s.Filter = (&(objectClass=groupOfUniqueNames)(cn=techSupport))
        s.SearchScope = SearchScope.Subtree
        results = s.FindAll
End Using
```

* First we are declaring a variable to hold our search results.
* Next we open up a connection to the LDAP directory. This is done by instantiating a DirectoryEntry object. The DirectoryEntry object requires the connection path in the form of a URL `LDAP://MyServer:10389/OU=subdir,O=parent`, the principle `uid=myuser,ou=system`, credentials `mypassword`, and the method of authentication (this will depend upon your LDAP directory).
* In order to search the directory we need to use the DirectorySearcher Object. We assign our DirectoryEntry object to the SearchRoot property, this will tell the DirectorySearcher where to base its search. The Filter property needs the details of what we are searching for, in this example we are looking for an entry whose ObjectClass is `groupOfUniqueNames` and CN is `techSupport`. The ampersand in front of the query tells the searcher this is an AND operation. The SearchScope property tells the searcher that we want to search the whole sub tree from the SearchRoot down.
* Lastly we return the results.

This is a very basic example of searching the directory. The directory is searchable on any property that an object may have, e.g. you may want to find all entries whose are inetOrgPerson and have a surname of smith. In that example your filter would be `(&(objectClass=inetOrgPerson)(sn=Smith))`

### Performing An Update

You can perform an update on a directory entry just like you can in a database. When performing an update it is important to remember an entry can have multiple properties of the same name. In other words the properties are in fact arrays. The following is an example of an update.

```vbnet
Public Sub UpdateUser(ByVal username as String, ByVal firstName as String, ByVal surname as String)

        Dim myUserDN As String = String.Format("{0}uid={1},{2}", _settings.LDAPUrl, username, _settings.UsersDN)
	Using u As New DirectoryEntry(myUserDN, _settings.Principle, _settings.Credentials, AuthenticationTypes.ServerBind)
	    AddUpdateProperty(u, "cn", firstName)
            AddUpdateProperty(u, "sn", surname)
 	    u.CommitChanges()
	End Using
End Sub

Private Sub AddUpdateProperty(ByVal r As DirectoryEntry, ByVal propName As String, ByVal value As Object)
        If r.Properties(propName).Count = 0 Then
            r.Properties(propName).Add(value)
        Else
            r.Properties(propName).Item(0) = value
	End If
End Sub
```

The above code shows two sub routines. Lets look at the first one, UpdateUser:

* First we construct the URL to the object we want. We supply the LDAP URL along with the path to the entry we want.
* Next we attempt to connect straight to our entry using the DirectoryEntry object. If the object is not found this line will throw a DirectoryServicesCOMException exception.
* Now we can go ahead and update the properties we need to change. This is done via a helper function to handle the fact the entry could contain none, one or many of the property.
* Lastly we call the CommitChanges method on the Directory Entry.

### Performing An Insert

Performing an insert on the directory is very similar to performing an update. The code below shows how we can insert a new user type entry.

```vbnet
Using users As New DirectoryEntry(userDNRoot, _settings.Principle, _settings.Credentials, AuthenticationTypes.ServerBind)
    Using newUser As DirectoryEntry = users.Children.Add(String.Format("uid={0}", username), "person")

        ' add user required properties
        AddUpdateProperty(newUser, "cn", forename)
        AddUpdateProperty(newUser, "sn", surname)
        newUser.CommitChanges()
    End Using
End Using
```

Lets look at the code:

* We need to connect to the LDAP directory. This time we connect to the root DN of where we want to add our new entry. Think of this as XML, we are going to add a child entry to the root.
* Once we have a connection, we can use the Children.Add methods to create a new DirectoryEntry object. As a parameter we pass in the name of the entry.
* Using the same helper function we saw above in the update functionality we create the properties on the object (note that this is a shortened list).
* Once we have assigned all the properties we go ahead and commit changes.

