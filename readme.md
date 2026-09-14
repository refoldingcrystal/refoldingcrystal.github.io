# Personal website

Static site generator written in lua, alongside all the content on my website

## Usage

```bash
lua gen.lua [src_dir] [docs_dir] [options]
```

## Options

- `-w`, `--watch` - watches `src_dir` and rebuilds on change, while running a http server
- `-p`, `--port PORT` - port for the server, default: `8000`

## Requirements

The script requires `lunamark` and `penlight`. Install it with:

```bash
luarocks install lunamark penlight
```

## Todo

- [ ] proper sitemap
- [ ] outline of current page on the margin
- [ ] better rss generator
- [ ] file locking to speed up generation
- [ ] remove jekyll from github actions
