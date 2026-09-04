using System;
using Cloud5mins.ShortenerTools.Core.Domain;
using Cloud5mins.ShortenerTools.Core.Messages;
using System.Text.Json;

namespace Cloud5mins.ShortenerTools.TinyBlazorAdmin;

public class UrlManagerClient(HttpClient httpClient)
{

	public async Task<IQueryable<ShortUrlEntity>?> GetUrls()
    {
		IQueryable<ShortUrlEntity>? urlList = null;
		try{
			using var response = await httpClient.GetAsync("/api/UrlList");
			if(response.IsSuccessStatusCode){
				var urls = await response.Content.ReadFromJsonAsync<ListResponse>();
				urlList = urls!.UrlList.AsQueryable<ShortUrlEntity>();
			}
		}
		catch(Exception ex){
			Console.WriteLine(ex.Message);
		}
        
		return urlList;
    }

	public async Task<(bool , string)> UrlCreate(ShortRequest url)
	{
		(bool , string) result = (false, "Failed");
		try{
			using var response = await httpClient.PostAsJsonAsync<ShortRequest>("/api/UrlCreate", url);
			if(response.IsSuccessStatusCode){
				result = (true, "Success");
			}
			else{
				result = (false, await GetErrorMessageAsync(response));
			}
		}
		catch(Exception ex){
			Console.WriteLine(ex.Message);
			result = (false, ex.Message);
		}
		return result;
	}

	private static async Task<string> GetErrorMessageAsync(HttpResponseMessage response)
	{
		var statusText = $"{(int)response.StatusCode} {response.ReasonPhrase}".Trim();
		if (response.Content.Headers.ContentLength == 0)
		{
			return $"Request failed: {statusText}";
		}

		var mediaType = response.Content.Headers.ContentType?.MediaType ?? string.Empty;
		if (mediaType.Contains("json", StringComparison.OrdinalIgnoreCase))
		{
			try
			{
				var details = await response.Content.ReadFromJsonAsync<DetailedBadRequest>();
				if (!string.IsNullOrWhiteSpace(details?.Message))
				{
					return details.Message;
				}
			}
			catch (JsonException)
			{
				// Fall through to raw body fallback.
			}
		}

		var body = await response.Content.ReadAsStringAsync();
		if (string.IsNullOrWhiteSpace(body))
		{
			return $"Request failed: {statusText}";
		}

		var cleanedBody = body.Replace("\r", " ").Replace("\n", " ").Trim();
		if (cleanedBody.Length > 200)
		{
			cleanedBody = cleanedBody[..200] + "...";
		}

		return $"Request failed: {statusText}. {cleanedBody}";
	}

	public async Task<bool> UrlArchive(ShortUrlEntity shortUrl)
	{
		try{
			using var response = await httpClient.PostAsJsonAsync("/api/UrlArchive", shortUrl);
			if(response.IsSuccessStatusCode){
				return true;
			}
		}
		catch(Exception ex){
			Console.WriteLine(ex.Message);
		}
		
		return false;
	}

	public async Task<ShortUrlEntity?> UrlUpdate(ShortUrlEntity shortUrl)
	{
		try
		{
			using var response = await httpClient.PostAsJsonAsync("/api/UrlUpdate", shortUrl);
			if (response.IsSuccessStatusCode)
			{
				var updatedUrl = await response.Content.ReadFromJsonAsync<ShortUrlEntity>();
				return updatedUrl;
			}
		}
		catch (Exception ex)
		{
			Console.WriteLine(ex.Message);
		}

		return null;
	}

	public async Task<ClickDateList?> UrlClickStatsByDay(UrlClickStatsRequest statsRequest)
	{
		try
		{
			using var response = await httpClient.PostAsJsonAsync("/api/UrlClickStatsByDay", statsRequest);
			if (response.IsSuccessStatusCode)
			{
				var clickStats = await response.Content.ReadFromJsonAsync<ClickDateList>();
				return clickStats;
			}
		}
		catch (Exception ex)
		{
			Console.WriteLine(ex.Message);
		}

		return null;
	}


	public async Task<bool> ImportUrlDataAsync(UrlDetails urlData)
	{
		try
		{
			using var response = await httpClient.PostAsJsonAsync("/api/UrlDataImport", urlData);
			if (response.IsSuccessStatusCode)
			{
				return true;
			}
		}
		catch (Exception ex)
		{
			Console.WriteLine(ex.Message);
		}

		return false;
	}
	public async Task<bool> ImportClickStatsAsync(List<ClickStatsEntity> lstClickStats)
	{
		try
		{
			using var response = await httpClient.PostAsJsonAsync("/api/UrlClickStatsImport", lstClickStats);
			if (response.IsSuccessStatusCode)
			{
				return true;
			}
		}
		catch (Exception ex)
		{
			Console.WriteLine(ex.Message);
		}

		return false;
	}

}
