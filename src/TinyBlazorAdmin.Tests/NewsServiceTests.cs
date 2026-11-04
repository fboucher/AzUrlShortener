using System.Net;
using Cloud5mins.ShortenerTools.TinyBlazorAdmin.News;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace Cloud5mins.ShortenerTools.TinyBlazorAdmin.Tests;

public class NewsServiceTests
{
    private const string FeedUrl = "https://raw.githubusercontent.com/fboucher/AzUrlShortener/main/doc/news.md";
    private static readonly Uri FeedUri = new(FeedUrl);

    [Fact]
    public async Task Disabled_ReturnsNull_WithoutCallingTheFeed()
    {
        var handler = new FakeHandler(_ => Ok("## Hello"));
        var service = CreateService(handler, new NewsOptions { Enabled = false, FeedUrl = FeedUrl });

        var html = await service.GetNewsHtmlAsync();

        Assert.Null(html);
        Assert.Equal(0, handler.CallCount);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not a url")]
    [InlineData("ftp://example.com/news.md")]
    public async Task InvalidFeedUrl_ReturnsNull_WithoutCallingTheFeed(string feedUrl)
    {
        var handler = new FakeHandler(_ => Ok("## Hello"));
        var service = CreateService(handler, new NewsOptions { FeedUrl = feedUrl });

        Assert.Null(await service.GetNewsHtmlAsync());
        Assert.Equal(0, handler.CallCount);
    }

    [Fact]
    public async Task Enabled_RendersMarkdownToHtml()
    {
        var handler = new FakeHandler(_ => Ok("## New release\n\nVersion **4.0** is out."));
        var service = CreateService(handler, new NewsOptions { FeedUrl = FeedUrl });

        var html = await service.GetNewsHtmlAsync();

        Assert.NotNull(html);
        Assert.Contains("<h2", html);
        Assert.Contains("New release", html);
        Assert.Contains("<strong>4.0</strong>", html);
    }

    [Fact]
    public async Task SecondCall_IsServedFromCache()
    {
        var handler = new FakeHandler(_ => Ok("## Cached"));
        var cache = new MemoryCache(new MemoryCacheOptions());
        var service = CreateService(handler, new NewsOptions { FeedUrl = FeedUrl, CacheDurationMinutes = 60 }, cache);

        var first = await service.GetNewsHtmlAsync();
        var second = await service.GetNewsHtmlAsync();

        Assert.Equal(first, second);
        Assert.Equal(1, handler.CallCount);
    }

    [Fact]
    public async Task ExpiredCache_FetchesTheFeedAgain()
    {
        var handler = new FakeHandler(_ => Ok("## Fresh"));
        var cache = new MemoryCache(new MemoryCacheOptions());
        var service = CreateService(handler, new NewsOptions { FeedUrl = FeedUrl }, cache);

        await service.GetNewsHtmlAsync();
        cache.Remove(NewsService.CacheKeyPrefix + FeedUri.AbsoluteUri);
        await service.GetNewsHtmlAsync();

        Assert.Equal(2, handler.CallCount);
    }

    [Fact]
    public async Task HttpError_ReturnsNull()
    {
        var handler = new FakeHandler(_ => new HttpResponseMessage(HttpStatusCode.NotFound));
        var service = CreateService(handler, new NewsOptions { FeedUrl = FeedUrl });

        Assert.Null(await service.GetNewsHtmlAsync());
    }

    [Fact]
    public async Task NetworkFailure_ReturnsNull_AndIsCachedBriefly()
    {
        var handler = new FakeHandler(_ => throw new HttpRequestException("offline"));
        var service = CreateService(handler, new NewsOptions { FeedUrl = FeedUrl });

        Assert.Null(await service.GetNewsHtmlAsync());
        Assert.Null(await service.GetNewsHtmlAsync());
        Assert.Equal(1, handler.CallCount);
    }

    [Fact]
    public async Task EmptyFeed_ReturnsNull()
    {
        var handler = new FakeHandler(_ => Ok("   \n"));
        var service = CreateService(handler, new NewsOptions { FeedUrl = FeedUrl });

        Assert.Null(await service.GetNewsHtmlAsync());
    }

    [Theory]
    [InlineData("![logo](assets/logo.png)", "https://raw.githubusercontent.com/fboucher/AzUrlShortener/main/doc/assets/logo.png")]
    [InlineData("![logo](./assets/logo.png)", "https://raw.githubusercontent.com/fboucher/AzUrlShortener/main/doc/assets/logo.png")]
    [InlineData("[faq](faq.md)", "https://raw.githubusercontent.com/fboucher/AzUrlShortener/main/doc/faq.md")]
    [InlineData("[site](https://example.com/page)", "https://example.com/page")]
    public void RelativeUrls_AreResolvedAgainstTheFeedUrl(string markdown, string expectedUrl)
    {
        var html = NewsService.RenderMarkdown(markdown, FeedUri);

        Assert.NotNull(html);
        Assert.Contains($"\"{expectedUrl}\"", html);
    }

    [Fact]
    public void RawHtml_IsNotRendered()
    {
        var html = NewsService.RenderMarkdown("<script>alert('x')</script>\n\nHello", FeedUri);

        Assert.NotNull(html);
        Assert.DoesNotContain("<script>", html);
    }

    [Fact]
    public void JavascriptLinks_AreRemoved()
    {
        var html = NewsService.RenderMarkdown("[click](javascript:alert(1))", FeedUri);

        Assert.NotNull(html);
        Assert.DoesNotContain("javascript:", html);
    }

    private static NewsService CreateService(FakeHandler handler, NewsOptions options, IMemoryCache? cache = null) =>
        new(new HttpClient(handler),
            cache ?? new MemoryCache(new MemoryCacheOptions()),
            new StaticOptionsMonitor(options),
            NullLogger<NewsService>.Instance);

    private static HttpResponseMessage Ok(string content) =>
        new(HttpStatusCode.OK) { Content = new StringContent(content) };

    private sealed class FakeHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public int CallCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            CallCount++;
            return Task.FromResult(respond(request));
        }
    }

    private sealed class StaticOptionsMonitor(NewsOptions value) : IOptionsMonitor<NewsOptions>
    {
        public NewsOptions CurrentValue => value;
        public NewsOptions Get(string? name) => value;
        public IDisposable? OnChange(Action<NewsOptions, string?> listener) => null;
    }
}
