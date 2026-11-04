# News section in Tiny Blazor Admin

The home page of Tiny Blazor Admin displays a **News** section. It's used to push announcements to everyone running the URL shortener: a new version is available, storage needs to be upgraded, etc.

The news comes from a public Markdown file. By default it's [`doc/news.md`](news.md) from this repository, read from:

```
https://raw.githubusercontent.com/fboucher/AzUrlShortener/main/doc/news.md
```

## Publishing news (maintainers)

1. Edit [`doc/news.md`](news.md) and add the newest announcement at the top, usually with a `##` heading.
2. Put any image in [`doc/assets/`](assets/) and reference it with a relative path: `![description](assets/my-image.png)`. Relative links and images are resolved against the feed URL, so they work from the admin site.
3. Merge to `main`. Admin sites pick up the change once their cache expires (60 minutes by default).

Notes:

- Raw HTML in the file is not rendered (it's shown as text), to keep the admin site safe. Use plain Markdown: headings, paragraphs, lists, links, images, tables.
- Only `http`, `https` and `mailto` links are kept.
- If the file is empty, the News section is hidden.

## Configuring or disabling the News section (admins)

The section is configured in the `News` section of `src/TinyBlazorAdmin/appsettings.json`:

```json
"News": {
  "Enabled": true,
  "FeedUrl": "https://raw.githubusercontent.com/fboucher/AzUrlShortener/main/doc/news.md",
  "CacheDurationMinutes": 60
}
```

| Setting | Description |
|---|---|
| `Enabled` | `false` hides the News section entirely. No request is made. |
| `FeedUrl` | Public `http(s)` URL of any Markdown file. Point it to your own fork or file to publish your own news. |
| `CacheDurationMinutes` | How long the news is kept in memory before being downloaded again. |

When deployed (for example in Azure Container Apps), you can override these settings with environment variables on the admin container, without rebuilding:

```
News__Enabled=false
News__FeedUrl=https://raw.githubusercontent.com/<you>/<your-repo>/main/doc/news.md
News__CacheDurationMinutes=120
```

If the feed can't be reached, the home page still loads normally and the News section is simply not shown. The app retries a few minutes later.
