--- 
layout: post
title: "The Curse of the Evergreen Web"
comments: true
categories: [ technology ]
tags: [ web ]
---

With the release of Windows 10 Microsoft introduced a new browser, Edge, that promised to free us web developers from having to support IE 12 in 10 years time like we do with IE6 now. Edge is hardly the first browser to introduce constantly updated versions; Firefox and Chrome have been doing this for years. Most users of either of these browsers wouldn't have a clue what particular version of those browsers they're on. (Don't believe me? Quick, talk to a colleague, a friend, a relative and ask them if they're running Chrome 44 or Chrome 45. I'll wait...) This is something Scott Hanselman refers to as [The Evergreen Web](http://www.hanselman.com/blog/TheEvergreenWeb.aspx). In the article Scott talks about the importance of compatibility modes and as time progresses they're going to become more and more important. However when most developers think of browsers and compatibility modes they think rendering engines but I recently stumbled across some behaviour in Chrome 45 that was fundamentally different (and broken) as compared to the behaviour of Chrome 44. It made me realise there's a curse to the "Evergreen Web" - we developers seem to think it'll only ever mean things will get better. But humans write software and humans make mistakes. So bugs will ineveitably be introduced into the latest versions of browsers. Bugs that will break existing, well documented, standardised behaviour.

A little bit of background here; Many years ago the developers of the HTTP specification realised that connection speeds aren't infinite, that time outs happen, connections drop, and that resources can be large. So they implemented something called range requests and responses. When your browser talks to a server it tells the server "Hey! I want all of this resource!" it does this by using a request header of `Range: bytes=0-`. This tells the server that the web browser knows about range requests and it's currently requesting the range 0 to the end of the file. If the resource is hosted on even a remotely modern web server the server will respond with a slightly different response to normal. For one it will return a response code of `206 Partial Content` instead of a standard `200 OK` response. Additionally you'll see headers something like;

```
Accept-Ranges: bytes
Content-Length: 1234
Content-Range: bytes 0-1233/1234
```

This tells the web browser "FYI: I can accept byte ranges! Anyway, this file content is 1234 bytes long. And this response is the range of bytes from 0-1233 (for a length of 1234)!". The client goes about it's merry way and starts consuming the response from the server. But, alas, alark, after byte 400 your internet connection dies! A few moments later it comes back up and you try downloading that same file. Instead of requesting the entire thing your browser, knowing that the resource came from a server that supports range requests/responses, will alter the request for the resource. This time when it requests the resource it'll insert a header `Range: bytes=400-1233`. Now when the server receives this it'll know to skip the first 400 bytes. It'll respond with another `206 Partial Content` response with headers akin to;

```
Accept-Ranges: bytes
Content-Length: 834
Content-Range: bytes 400-1233/1234
```

Then your browser knows when re-assembling the file that this response goes on the end of its prior response from the server and voila! You have the entire file without having to request the entire thing again. In our simplistic example we're talking about saving a few hundred bytes and, well, who cares? But imagine the file wasn't 1234 bytes. What if it was 100mb? 1,000mb? 4,000mb? And what if you were on a slow connection? Or a connection where you pay for data? It starts to become a pretty useful feature.

But, that's not all, this can be combined with other great "modern" features. Let's say I have an audio file on my webpage. I hear there's sites out [there](http://www.soundcloud.com) that do this kind of craziness. Now I click play on an MP3 but I've already heard the first half of it so I skip halfway through the file. A smart browser can look at the response from the server and make an educated guess that if the user has clicked halfway through the MP3 then it can terminate the current request and just request from the halfway point of the file. In fact, I have such an example of this happening...

![Soundcloud Partial Response](/img/posts/2015-09-12-the-curse-of-the-evergreen-web/chrome-44-206-behaviour.gif "Partial Responses")

Here I am listening to Australian comedian [Wil Anderson](http://www.wilanderson.com.au/)'s podcast [TOFOP on Soundcloud](https://soundcloud.com/tofop). When I hit play my browser (Chrome 44, here) starts downloading and playing the MP3. When I skip to the end of the MP3 it terminates the existing download and starts a new download at my requested position. This is great - I'm not downloading the ~40mb of data inbetween those points that I don't care about and I hear audio at the new point almost instantly.

![Soundcloud Initial Request/Response](/img/posts/2015-09-12-the-curse-of-the-evergreen-web/chrome-44-initial-request.png "Initial Request/Response")

Looking through the response details you can see that my browser has indicated that it handles ranges and that the server has responded with a `206 Partial Content` and indicated the range that it has served.

![Soundcloud Subsequent Request/Response](/img/posts/2015-09-12-the-curse-of-the-evergreen-web/chrome-44-subsequent-request.png "Subsequent Request/Response")

Once I click later in the file we can see that my browser has made the second request with a specific `Range: bytes=...` request header. The server has responded with the appropriate range.

Now, what does any of this have to do with the "Evergreen Web" ? Well all of those requests were made whilst I was on Chrome 44. Now let's try the same thing on Chrome 45.

![Soundcloud No Partial Responses (FTTP)](/img/posts/2015-09-12-the-curse-of-the-evergreen-web/chrome-45-206-behaviour.gif "No Partial Responses (FTTP)")

Notice now when I through the file that the pause/play button has turned into a spinner? And that there is no termination of the connection and creation of a new request? I'm on a pretty quick connection where I am so it's not too bad too download the interim ~45mb of data. But it does interupt my listening experience. Let's just say that instead of being on a Fibre to the Premises connection I was on WiFi...

![Soundcloud No Partial Responses (WiFi)](/img/posts/2015-09-12-the-curse-of-the-evergreen-web/chrome-45-wifi-206-behaviour.gif "No Partial Responses (WiFi)")

Here I've used Chrome's bandwidth throttling to simulate a WiFi connection (Still a rather good connection, mind!) and notice how much longer I have to wait before the pause/play button stops spinning? Now imagine I'm on a 3G connection. Or a DSL2 connection (which I tried to show you but my screen recording software actually crashed because it took too long).

Ignoring the horrible user experience here there's also a, potential, monetary cost. As a consumer you might be spending additional money (or time) to download that unwanted data. And if you're hosting resources? Well you just threw those 45mb of data to a client that didn't even want them. Chrome 45 was only released on the [1st of September](https://en.wikipedia.org/wiki/Google_Chrome_release_history) but in those two weeks it already has [~23.93% of the browser market share](http://gs.statcounter.com/#browser_version-ww-daily-20150901-20150911-bar). That's a lot of users potentially wasting a lot of data.

I should point out that this problem is, currently, only present in Chrome 45 when dealing with MP3s. It seems to have been done as part of a bug fix that meant that Chrome < 45 required [XING/INFO headers even on CBR MP3s to seek](https://code.google.com/p/chromium/issues/detail?id=397365). For most people this probably isn't a huge problem but I just spent two days playing around with potential work arounds. The Chrome team's response to this is that they'll have it [fixed for Chromium 47](https://code.google.com/p/chromium/issues/detail?id=530043#c10). I'm not 100% sure on the cycle between Chrome and Chromium but Chromium 45 was branched on [July 10th](https://www.chromium.org/developers/calendar) and Chrome 45 got released on the [1st of September](https://en.wikipedia.org/wiki/Google_Chrome_release_history). Chromium 47 is scheduled to be branched on [October 2nd](https://www.chromium.org/developers/calendar) - if there's a similar branch to release gap we'll be living with this bug until December. In the mean time I guess a lot of MP3 bits will be getting streamed to `/dev/null`.

It does make me wonder though; if an issue like this is going to take the Chrome team weeks, or months, to fix are we running the risk that people will start to build to these behaviours? Maybe someone, somewhere, uses this feature to force a user to have a degraded experience if they try to skip through an ad. Not the best example but I can definitely envision a point where people build web features utilising the exact behaviour of a browser version. And if  web developers start to rely on features specific to a range of browser versions is it going to become a [Quirks Mode](https://en.wikipedia.org/wiki/Quirks_mode) that the browser maintainers have to implement? Is someone one day going to include a `<meta>` tag in the `<head>` of their document to get newer versions of Chrome to break range requests for MP3 files?

Until Chrome 47 lands, then, if you want to skip through audio files on the web you have a few options; you can try using AAC files instead, you can use Chrome 44, or you can use another browser. 

Note: If you a developer affected by this and you manage to find a work around please let me know!

**UPDATE 2015-09-16**: The Chrome team is now aiming to get this out in time for [Chrome 46](https://code.google.com/p/chromium/issues/detail?id=530043#c15). I still have no exact idea of the timeline of when that will be. But it's better news than having to wait for 47. 