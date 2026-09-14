local ok_pl, path = pcall(require, "pl.path")
local _, dir = pcall(require, "pl.dir")
local _, file = pcall(require, "pl.file")
if not ok_pl then
    io.stderr:write("error: script requires penlight\n")
    os.exit(1)
end

local ok_md, lunamark = pcall(require, "lunamark")
if not ok_md then
    io.stderr:write("error: script requires lunamark\n")
    os.exit(1)
end

local writer = lunamark.writer.html.new()
local render_markdown = lunamark.reader.markdown.new(writer, {
    smart = true,
    fenced_code_blocks = true,
    fenced_code_attributes = true
})

local SITE_URL = "https://lozinka.duckdns.org"

local function html_escape(s)
    local map = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }
    return (s:gsub("[&<>\"]", map))
end

local function format_title(name)
    return (name:gsub("[-_]", " "))
end

local function get_stem(p)
    local base, _ = path.splitext(path.basename(p))
    return base
end

local function relative_path(target, start)
    local t, s = {}, {}
    for part in target:gmatch("[^/]+") do table.insert(t, part) end
    for part in start:gmatch("[^/]+") do table.insert(s, part) end

    local common = 1
    while common <= #t and common <= #s and t[common] == s[common] do
        common = common + 1
    end

    local out = {}
    for _ = common, #s do table.insert(out, "..") end
    for j = common, #t do table.insert(out, t[j]) end
    return #out == 0 and "." or table.concat(out, "/")
end

local function strip_quotes(s)
    s = s:match("^%s*(.-)%s*$") or ""
    local q = s:match('^"(.*)"$') or s:match("^'(.*)'$")
    return q or s
end

-- accepts YYYY-MM-DD or YYYY-MM-DD[T ]HH:MM:SS
local function parse_date(s)
    local y, mo, d, h, mi, se = s:match("^(%d%d%d%d)-(%d%d)-(%d%d)[T ]?(%d?%d?):?(%d?%d?):?(%d?%d?)")
    if not y then return nil end
    return os.time({
        year = tonumber(y),
        month = tonumber(mo),
        day = tonumber(d),
        hour = tonumber(h) or 0,
        min = tonumber(mi) or 0,
        sec = tonumber(se) or 0
    })
end

local function parse_frontmatter(content)
    if content:sub(1, 3) ~= "---" then
        return {}, content
    end

    local fm_body, rest = content:match("^%-%-%-[ \t]*\r?\n(.-)\r?\n%-%-%-[ \t]*\r?\n?(.*)$")
    if not fm_body then
        return {}, content
    end

    local meta = {}
    for line in (fm_body .. "\n"):gmatch("(.-)\r?\n") do
        if line:match("%S") and not line:match("^%s*#") then
            local key, value = line:match("^%s*([%w_]+)%s*:%s*(.-)%s*$")
            if key then meta[key] = strip_quotes(value) end
        end
    end

    return meta, rest
end

local function parse_document(filepath)
    local content = file.read(filepath) or ""
    local meta, body = parse_frontmatter(content)

    local has_title = meta.title ~= nil and meta.title ~= ""
    local title = has_title and meta.title or format_title(get_stem(filepath))

    local parsed_date = meta.date and parse_date(meta.date)
    local has_date = parsed_date ~= nil
    local date = has_date and parsed_date or path.getmtime(filepath)

    return { title = title, date = date, tags = meta.tags, body = body, has_title = has_title, has_date = has_date }
end

local function get_title(filepath)
    return parse_document(filepath).title
end

-- when a markdown page is nested in a folder
local function fix_relative_links(html)
    local function replacer(attr, pre, url)
        if url:match("^%a[%w%+%.%-]*:") or url:match("^//") or url:match("^/") or url:match("^#") then
            return string.format('%s=%s"%s"', attr, pre, url)
        end
        return string.format('%s=%s"../%s"', attr, pre, url)
    end

    html = html:gsub('src=(%s*)"([^"]+)"', function(pre, url) return replacer("src", pre, url) end)
    html = html:gsub('href=(%s*)"([^"]+)"', function(pre, url) return replacer("href", pre, url) end)
    return html
end

local function snapshot(content_dir)
    local snap = {}
    for _, f in ipairs(dir.getallfiles(content_dir) or {}) do
        snap[f] = path.getmtime(f)
    end
    return snap
end

local function snapshots_equal(a, b)
    for p, mtime in pairs(a) do if b[p] ~= mtime then return false end end
    for p in pairs(b) do if a[p] == nil then return false end end
    return true
end

local Site = {}

local function needs_rebuild(src, dest)
    -- TODO: write file lock
    return true
end

local PAGE_TEMPLATE = [[<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<link rel="stylesheet" href="%s">
</head>
<body>
%s%s
</body>
</html>
]]

function Site.build_page(content_html, title, dest_dir, output_dir)
    -- TODO: change path of style.css to src/
    local css_href = relative_path(path.join(output_dir, "style.css"), dest_dir)
    local back_link = dest_dir ~= output_dir and '<p class="back"><a href="..">../</a></p>\n' or ""
    return string.format(PAGE_TEMPLATE, html_escape(title), css_href, back_link, content_html)
end

function Site.convert_file(src, dest_dir, output_dir, is_index)
    local out_file = path.join(dest_dir, "index.html")
    if not needs_rebuild(src, out_file) then return end

    local doc = parse_document(src)
    local body_html = render_markdown(doc.body)

    -- correct only if not index.md
    if not is_index then body_html = fix_relative_links(body_html) end

    if doc.has_title then
        local date_html = doc.has_date and
        string.format('<span class="post-date">%s</span>', os.date("!%Y-%m-%d", doc.date)) or ""
        body_html = string.format('<div class="post-header"><h1>%s</h1>%s</div>\n%s',
            html_escape(doc.title), date_html, body_html)
    end

    dir.makepath(dest_dir)
    file.write(out_file, Site.build_page(body_html, doc.title, dest_dir, output_dir))
end

function Site.build_listing(dir_path, dest_dir, output_dir, md_files, index_file)
    local out_file = path.join(dest_dir, "index.html")
    if not needs_rebuild(dir_path, out_file) then return end

    table.sort(md_files, function(a, b) return path.basename(a) > path.basename(b) end)

    local items = {}
    for _, f in ipairs(md_files) do
        local label = get_title(f)
        table.insert(items, string.format('<li><a href="%s/">%s</a></li>', get_stem(f), html_escape(label)))
    end

    local index_html, index_title = "", nil
    if index_file ~= nil then
        local index_doc = parse_document(index_file)
        index_html = render_markdown(index_doc.body)
        index_title = index_doc.title
    end

    local title = index_title or format_title(path.basename(dir_path))
    local parts = { string.format("<h1>%s</h1>", html_escape(title)) }

    if index_html ~= "" then table.insert(parts, index_html) end
    if #items > 0 then
        table.insert(parts, string.format("<p><i>%d items</i></p>", #items))
        table.insert(parts, '<ul style="list-style: none;">\n' .. table.concat(items, "\n") .. '\n</ul>')
    end

    dir.makepath(dest_dir)
    file.write(out_file, Site.build_page(table.concat(parts, "\n"), title, dest_dir, output_dir))
end

local RSS_ITEM_TEMPLATE = [==[
    <item>
        <title>%s</title>
        <link>%s</link>
        <guid>%s</guid>
        <pubDate>%s</pubDate>
        <description><![CDATA[%s]]></description>
    </item>
]==]

local function rfc822_date(timestamp)
    return os.date("!%a, %d %b %Y %H:%M:%S GMT", timestamp)
end

local function post_url_path(stuff_dir, mdfile)
    local rel = path.relpath(mdfile, stuff_dir)
    local rel_dir = path.dirname(rel)
    local stem = get_stem(mdfile)
    if stem == "index" then
        return (rel_dir == "" or rel_dir == ".") and "/stuff/" or ("/stuff/" .. rel_dir .. "/")
    end
    return "/stuff/" .. ((rel_dir ~= "" and rel_dir ~= ".") and (rel_dir .. "/") or "") .. stem .. "/"
end

function Site.build_rss(content_dir, output_dir, site_url)
    local stuff_dir = path.join(content_dir, "stuff")
    if not path.isdir(stuff_dir) then return end

    local md_files = {}
    for _, f in ipairs(dir.getallfiles(stuff_dir) or {}) do
        if f:match("%.md$") then table.insert(md_files, f) end
    end

    local docs = {}
    for _, f in ipairs(md_files) do
        docs[f] = parse_document(f)
    end
    table.sort(md_files, function(a, b) return docs[a].date > docs[b].date end)

    local items = {}
    for _, f in ipairs(md_files) do
        local doc = docs[f]
        local url = site_url .. post_url_path(stuff_dir, f)
        table.insert(items, string.format(RSS_ITEM_TEMPLATE,
            html_escape(doc.title), url, url,
            rfc822_date(doc.date),
            render_markdown(string.format("Post from lozinka %q", html_escape(doc.title)))))
    end

    local rss = string.format([[
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
    <channel>
    <title>%s</title>
    <link>%s</link>
    <description>%s</description>
    %s</channel>
</rss>
]], html_escape("lozinka"), site_url, html_escape("latest posts"), table.concat(items))

    file.write(path.join(output_dir, "rss.xml"), rss)
end

function Site.build(content_dir, output_dir)
    dir.makepath(output_dir)

    local source_dir = path.dirname(debug.getinfo(1, "S").source:match("^@?(.*)$"))
    local style_src = path.join(source_dir, "style.css")
    local style_dst = path.join(output_dir, "style.css")

    if path.exists(style_src) and needs_rebuild(style_src, style_dst) then
        file.copy(style_src, style_dst)
    end

    local function process_dir(root)
        local rel = relative_path(root, content_dir)
        local dest_root = (rel == ".") and output_dir or path.join(output_dir, rel)

        local md_files, other_files = {}, {}
        for _, full_path in ipairs(dir.getdirectories(root) or {}) do
            process_dir(full_path)
        end

        for _, full_path in ipairs(dir.getfiles(root) or {}) do
            local name = path.basename(full_path)
            if name:match("%.md$") then
                table.insert(md_files, full_path)
            else
                table.insert(other_files, name)
            end
        end

        local index_file = nil
        if rel ~= "." then
            for _, f in ipairs(md_files) do
                if get_stem(f) == "index" then
                    index_file = f; break
                end
            end

            local listing_files = {}
            for _, f in ipairs(md_files) do
                if f ~= index_file then table.insert(listing_files, f) end
            end
            Site.build_listing(root, dest_root, output_dir, listing_files, index_file)
        end

        for _, f in ipairs(md_files) do
            if rel == "." and get_stem(f) == "index" then
                Site.convert_file(f, output_dir, output_dir, true)
            elseif f ~= index_file then
                Site.convert_file(f, path.join(dest_root, get_stem(f)), output_dir, false)
            end
        end

        for _, name in ipairs(other_files) do
            local src_file = path.join(root, name)
            local dest_file = path.join(dest_root, name)
            if needs_rebuild(src_file, dest_file) then
                dir.makepath(path.dirname(dest_file))
                file.copy(src_file, dest_file)
            end
        end
    end

    process_dir(content_dir)
    Site.build_rss(content_dir, output_dir, SITE_URL)
end

local function serve_request(client, output_dir)
    client:settimeout(2)
    local req_line = client:receive("*l")
    if not req_line then return end
    local method, raw_path = req_line:match("^(%u+)%s+(%S+)%s+HTTP")
    if not method then return end

    while client:receive("*l") ~= "" do end

    local req_path = raw_path:match("^[^?#]*"):gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    req_path = req_path:gsub("%.%.", "")

    local fs_path = path.join(output_dir, req_path:sub(2))
    if fs_path == "" then fs_path = output_dir end
    if path.isdir(fs_path) then fs_path = path.join(fs_path, "index.html") end

    if path.exists(fs_path) and not path.isdir(fs_path) then
        local body = file.read(fs_path)
        client:send(string.format("HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s", #body, body))
    else
        local body = "<h1>404 Not Found</h1>"
        client:send(string.format(
            "HTTP/1.1 404 Not Found\r\nContent-Type: text/html\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s",
            #body,
            body))
    end
end

local function run_watch(content_dir, output_dir, port, interval)
    Site.build(content_dir, output_dir)
    local prev_snap = snapshot(content_dir)

    local socket = require("socket")
    local server = assert(socket.bind("*", port))
    server:settimeout(0)

    print(string.format("Watching %q for changes... Serving on http://localhost:%d/ (Ctrl+C to stop)", content_dir, port))

    while true do
        local readable = socket.select({ server }, nil, interval)
        if readable and #readable > 0 then
            local client = server:accept()
            if client then
                pcall(serve_request, client, output_dir); client:close()
            end
        end

        local curr_snap = snapshot(content_dir)
        if not snapshots_equal(prev_snap, curr_snap) then
            print(string.format("[%s] change detected, rebuilding...", os.date("%H:%M:%S")))
            pcall(Site.build, content_dir, output_dir)
            prev_snap = curr_snap
        end
    end
end

local function main()
    local watch, port, content_dir, output_dir = false, 8000, "content", "dist"
    local i = 1

    while i <= #arg do
        if arg[i] == "-w" or arg[i] == "--watch" then
            watch = true
        elseif arg[i] == "-p" or arg[i] == "--port" then
            i = i + 1; port = tonumber(arg[i])
        elseif not arg[i]:match("^-") then
            if content_dir == "content" then
                content_dir = arg[i]
            else
                output_dir = arg[i]
            end
        end
        i = i + 1
    end

    if not path.isdir(content_dir) then
        io.stderr:write(string.format("error: content directory %q not found\n", content_dir))
        os.exit(1)
    end

    if watch then
        run_watch(content_dir, output_dir, port, 1)
    else
        local ok, err = pcall(Site.build, content_dir, output_dir)
        if not ok then
            io.stderr:write("build error: " .. tostring(err) .. "\n"); os.exit(1)
        end
        print(string.format("Built %s -> %s", content_dir, output_dir))
    end
end

main()
