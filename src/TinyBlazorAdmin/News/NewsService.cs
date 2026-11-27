using Markdig;
using Markdig.Syntax;
using Markdig.Syntax.Inlines;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace Cloud5mins.ShortenerTools.TinyBlazorAdmin.News;

/// <summary>
/// Downloads the public Markdown news feed, converts it to HTML and caches the result.
/// </summary>
public class NewsService : INewsService
{
    internal const string CacheKeyPrefix = "news-feed:";

    // When the feed can't be retrieved, wait a bit before trying again so a GitHub
    // outage doesn't slow down every home page load.
    internal static readonly TimeSpan FailureCacheDuration = TimeSpan.FromMinutes(5);

    private static readonly MarkdownPipeline Pipeline = new MarkdownPipelineBuilder()
        // Only extensions that can't inject attributes or scripts (no GenericAttributes).
        .UsePipeTables()
        .UseEmphasisExtras()
        .UseTaskLists()
        .UseAutoLinks()
        .DisableHtml() // raw HTML in the feed is rendered as text, never as markup
        .Build();

    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;
    private readonly IOptionsMonitor<NewsOptions> _options;
    private readonly ILogger<NewsService> _logger;

    public NewsService(HttpClient httpClient, IMemoryCache cache, IOptionsMonitor<NewsOptions> options, ILogger<NewsService> logger)
    {
        _httpClient = httpClient;
        _cache = cache;
        _options = options;
        _logger = logger;
    }

    public async Task<string?> GetNewsHtmlAsync(CancellationToken cancellationToken = default)
    {
        var options = _options.CurrentValue;
        if (!options.Enabled || string.IsNullOrWhiteSpace(options.FeedUrl))
        {
            return null;
        }

        if (!Uri.TryCreate(options.FeedUrl, UriKind.Absolute, out var feedUri)
            || (feedUri.Scheme != Uri.UriSchemeHttps && feedUri.Scheme != Uri.UriSchemeHttp))
        {
            _logger.LogWarning("News feed URL '{FeedUrl}' is not a valid http(s) URL. News section is hidden.", options.FeedUrl);
            return null;
        }

        var cacheKey = CacheKeyPrefix + feedUri.AbsoluteUri;
        if (_cache.TryGetValue(cacheKey, out string? cached))
        {
            return cached;
        }

        string? html = null;
        var cacheDuration = TimeSpan.FromMinutes(Math.Max(1, options.CacheDurationMinutes));
        try
        {
            using var response = await _httpClient.GetAsync(feedUri, cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                var markdown = await response.Content.ReadAsStringAsync(cancellationToken);
                html = RenderMarkdown(markdown, feedUri);
            }
            else
            {
                _logger.LogWarning("News feed '{FeedUrl}' returned {StatusCode}.", feedUri, (int)response.StatusCode);
                cacheDuration = Min(cacheDuration, FailureCacheDuration);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Unable to retrieve the news feed '{FeedUrl}'.", feedUri);
            cacheDuration = Min(cacheDuration, FailureCacheDuration);
        }

        _cache.Set(cacheKey, html, cacheDuration);
        return html;
    }

    /// <summary>
    /// Converts the Markdown to HTML. Relative links and images are resolved against
    /// <paramref name="feedUri"/> so that <c>assets/image.png</c> points next to the feed,
    /// and links using a scheme other than http(s)/mailto are removed.
    /// </summary>
    internal static string? RenderMarkdown(string? markdown, Uri feedUri)
    {
        if (string.IsNullOrWhiteSpace(markdown))
        {
            return null;
        }

        var document = Markdown.Parse(markdown, Pipeline);

        foreach (var link in document.Descendants<LinkInline>())
        {
            link.Url = ResolveUrl(link.Url, feedUri) ?? string.Empty;
        }

        foreach (var reference in document.Descendants<AutolinkInline>())
        {
            if (!reference.IsEmail && ResolveUrl(reference.Url, feedUri) is null)
            {
                reference.Url = string.Empty;
            }
        }

        var html = document.ToHtml(Pipeline);
        return string.IsNullOrWhiteSpace(html) ? null : html;
    }

    internal static string? ResolveUrl(string? url, Uri feedUri)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return url;
        }

        var trimmed = url.Trim();

        // In-page anchors stay as they are.
        if (trimmed.StartsWith('#'))
        {
            return trimmed;
        }

        if (Uri.TryCreate(trimmed, UriKind.Absolute, out var absolute)
            && !(absolute.IsFile && !trimmed.StartsWith("file:", StringComparison.OrdinalIgnoreCase)))
        {
            return IsSafeScheme(absolute) ? absolute.AbsoluteUri : null;
        }

        if (Uri.TryCreate(feedUri, trimmed, out var resolved) && IsSafeScheme(resolved))
        {
            return resolved.AbsoluteUri;
        }

        return null;
    }

    private static bool IsSafeScheme(Uri uri) =>
        uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeMailto;

    private static TimeSpan Min(TimeSpan a, TimeSpan b) => a < b ? a : b;
}
