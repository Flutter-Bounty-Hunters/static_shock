---
title: What is a static site?
---
A static site is a website in which all content is available at build
time, i.e., doesn't involve content submitted by users after deployment.

Common uses for static sites include marketing pages, blogs, and documentation
websites.

Some examples of dynamic websites (not static) include Facebook, GMail, GitHub,
and YouTube. These sites, and similar, can't be fully generated at build time
because their content is created by users.

Static sites are comprised of traditional browser files: HTML, CSS, JavaScript,
images, audio, and video. It's the developer or author's responsibility to
create these files. 

In practice, it's impractical to write all the HTML by hand. Every new blog post 
or documentation page requires repeating similar headers, and surrounding each
bit of text with appropriate HTML tags. It's tedious and error prone.

This is why the world invented static site generators.

## What is a static site generator?
A static site generator is a set of tools that help developers and authors
easily and quickly generate a static website from author-friendly files.

A static website is always deployed as HTML, CSS, JavaScript, and assets.

With a static site generator, those static site files can be created from
a different set of files, which are easier to write.

Static Shock ships with the following tools to reduce the workload:
 * Markdown for writing posts (instead of HTML)
 * Jinja for layout templates (instead of HTML)
 * SCSS and Tailwind for styling (instead of CSS)
 * Draft mode to write posts without publishing them
 * A redirect page generator
 * An RSS feed generator
 * A website screenshot generator

Each of these tools either completely automates a task that an author
would have to do by hand, or reduces the effort that an author would 
need to spend.

Also, Static Shock is pluggable - developers can add new tools, themselves.
This way, Static Shock can become whatever an author needs it to be.