# Writing a static site generator

*2026-09-11*

I wanted a blog. So now I have one. Reaching for Hugo or Jekyll seemed like the obvious move, until I noticed the sheer overhead of setting either one up. They're great tools, but neither is as simple to use as the 250-line generator I wrote myself. Here's how I built it, and how it's working out so far.

## Why not use an already-existing tool?

1. It's a personal blog for my own rants, not a sophisticated site with a mountain of content. I will never have so many posts that rendering speed becomes something to worry about. The features I actually need are headings, basic text formatting, images. Writing a generator around just those, means its configuration and behavior are made for me, not for every use case a general-purpose tool has to support.
2. Portability. My generator has no external dependencies making it run anywhere Python is installed. There's no install step, no configuration file, no lockfile to keep in sync. It will work the same way in ten years as it does today, which isn't a guarantee I can make about a Hugo or Jekyll setup, where a toolchain upgrade can quietly break a build.
3. When something fails or breaks in my generator, I have to understand the issue myself, work out a fix, and apply it without framework abstraction standing between me and the bug. Since I know exactly what my generator does and how, fixing an issue or adding a new feature is far more appealing than digging through someone else's plugin system.
4. The only job of this generator is to turn Markdown into HTML, so adopting an existing tool means adopting its entire ecosystem, including a long list of features I'll never use.

None of this means Hugo is a bad tool. It just means that, for a project this size, the framework overshadows the actual purpose and ends up overwhelming the person using it.

## Design decisions

There's exactly one template in the entire generator:

```html
<!DOCTYPE html>
<html lang="en">
<head>
...
<title>{title}</title>
<link rel="stylesheet" href="{css_href}">
</head>
<body>
{back_link}{content}
</body>
</html>
```

I wanted to stay clear of Jinja, to avoid a "language within a language" situation and to avoid pulling in a dependency I don't actually need. A nice side effect of using plain `.format()` instead of a templating engine is that I never re-parse the page content; only the template string itself gets scanned for placeholders. In practice this means that if a post happens to contain a literal `{placeholder}` looking string it won't break rendering. I'm glad I didn't start out building templates with f-strings and several layers of string concatenation instead, because I suspect I'd have run into exactly that problem.

The build itself is a single walk over the content directory using `os.walk`. For every folder, it builds a listing of that folder's contents, any non-Markdown file is copied to the output directory unchanged and every post gets its own directory - `example/index.html` instead of `example.html`, so the url is left without a file extension. If a directory contains an `index.md` file, its contents are rendered as the intro text on that folder's listing page, shown above the generated list of posts.

The sitemap is built as a second pass over the output searching for every `index.html`. Of course this could be achieved in the first pass over the content directory instead of being redone afterward, but it works, and for now that's what matters.

One decision made purely for simplicity was to re-render every page on every run rather than build incrementally. I expected that to have a real impact on build time, but in practice a full rebuild takes less than `0.1s`, so until my site is large enough for that to matter, it's not worth the added complexity of caching or change detection.

The one feature I still consider genuinely important, and haven't built yet, is a live preview. Right now, checking how a post looks means switching to a terminal tab, re-running the build, starting an HTTP server, and switching to the browser every single time I make an edit. That loop is tedious enough to discourage small revisions, which is the opposite of what a writing tool should do. It's the next thing on my list.

## Where this leaves me

The generator does exactly what I need and nothing else, which was the whole point. All the other features offered by existing tools can be easily built into my own version if I would ever have decided that they are needed for my purposes.
