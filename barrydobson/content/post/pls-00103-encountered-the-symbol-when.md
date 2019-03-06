+++
author = "Barry Dobson"
categories = ["Oracle", "VB", "Archives"]
date = 2009-02-17T07:16:00Z
description = ""
draft = false
cover = "https://images.unsplash.com/photo-1504355080015-bba52674577b?ixlib=rb-0.3.5&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=1080&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ&s=54733a3c1965933aab5f6c9a509f4ec3"
slug = "pls-00103-encountered-the-symbol-when"
tags = ["Oracle", "VB", "Archives"]
title = "PLS-00103: Encountered the symbol \"\" WHEN expecting one OF the following"

+++

I recently came across this error whilst developing stored procedures in oracle. The stored procedure will be built in Oracle but marked as invalid. Trying a re-compile will give you the above error.

The problem appears to be with Windows CRLF characters on line breaks. Oracle does not treat this as white space, instead it sees it as an empty string. In order to get round this problem, convert the CRLF characters to LF characters and Oracle should be happy.

