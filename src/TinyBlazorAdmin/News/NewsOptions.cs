namespace Cloud5mins.ShortenerTools.TinyBlazorAdmin.News;

/// <summary>
/// Settings for the News section displayed on the TinyBlazorAdmin home page.
/// Bound to the "News" configuration section (e.g. appsettings.json or the
/// environment variables News__Enabled, News__FeedUrl, News__CacheDurationMinutes).
/// </summary>
public class NewsOptions
{
    public const string SectionName = "News";

    public const string DefaultFeedUrl = "https://raw.githubusercontent.com/fboucher/AzUrlShortener/main/doc/news.md";

    /// <summary>Show or hide the News section on the home page.</summary>
    public bool Enabled { get; set; } = true;

    /// <summary>
    /// Public URL of the Markdown file containing the news. Relative links and images
    /// (e.g. <c>assets/picture.png</c>) are resolved against this URL.
    /// </summary>
    public string FeedUrl { get; set; } = DefaultFeedUrl;

    /// <summary>How long the downloaded news is kept in memory before being fetched again.</summary>
    public int CacheDurationMinutes { get; set; } = 60;
}
