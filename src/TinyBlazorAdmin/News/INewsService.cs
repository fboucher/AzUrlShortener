namespace Cloud5mins.ShortenerTools.TinyBlazorAdmin.News;

public interface INewsService
{
    /// <summary>
    /// Returns the news rendered as HTML, or <c>null</c> when the feed is disabled,
    /// empty or could not be retrieved. This method never throws.
    /// </summary>
    Task<string?> GetNewsHtmlAsync(CancellationToken cancellationToken = default);
}
