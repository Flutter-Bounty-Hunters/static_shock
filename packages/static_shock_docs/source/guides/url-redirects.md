---
title: URL Redirects
---
It's important to try not to ever publish a page with a public URL and then
move or delete that page without redirecting the URL. The original URL might
exist in various social media posts, as well as users' bookmarks.

You can use the `LinksPlugin` to [detect missing pages](/guides/find-missing-pages).

You can also use the `LinksPlugin` to setup page redirects, which we discuss here.

For any URL that you wish to redirect to another page, open the page where you want
the user to be redirected and set the `redirectFrom` property.

Example of a single URL redirect in a Markdown page:

```markdown
---
title: My Page to Redirect To
redirectFrom: /my/old/url/page.html
---
# My Page Content
```

Example of multiple URL redirects within a Markdown page:

```markdown
---
title: My Page to Redirect To
redirectFrom: 
 - /my/old/url/page-1.html
 - /my/old/url/page-2.html
---
# My Page Content
```

Example of a single URL redirect in a Jinja page:

```html
<!--
title: My Page to Redirect To
redirectFrom: /my/old/url/page.html
-->
<html>
<head></head>
<body></body>
</html>
```

Example of multiple URL redirects in a Jinja page:

```html
<!--
title: My Page to Redirect To
redirectFrom: 
 - /my/old/url/page-1.html
 - /my/old/url/page-2.html
-->
<html>
<head></head>
<body></body>
</html>
```

## How redirects work
Static sites don't do any server work, so you might wonder how URL redirects are
implemented.

To implement redirects, Static Shock makes a copy of your destination page for each
URL that you want to redirect. In other words, the same page might exist 2, 3, or 10
times in your final build, based on how many URLs you redirect there.

In addition to copying the page, Static Shock changes the HTML `<head>` so that the
browser is informed of the redirect. Typically, the browser will follow this redirect
on the user's behalf.
