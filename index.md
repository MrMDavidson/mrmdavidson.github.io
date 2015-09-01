---
layout : layout
title : michaeldavidson.me
---

<ul class="posts">
    {% for post in site.posts  limit:5 %}
		<li>
			<div class="idea">
				{% if forloop.first and post.layout == "post" %}
					<h1><a href="{{ post.url }}">{{ post.title }}</a></h1>
				{% else %}
					<h2><a class="postlink" href="{{ post.url }}">{{ post.title }}</a></h2>
				{% endif %}
				{% if post.categories %}
					<div>Posted under: 
						{% for category in post.categories %}
							<a href="/category/{{category}}">{{ category }}</a>{% if forloop.last == false %},{% endif %} 
						{% endfor %}
					</div>	
				{% endif %}
				{% if post.tags %}
					<div>Tags: 
						{% for tag in post.tags %}
							<a href="/tag/{{tag}}">{{ tag }}</a>{% if forloop.last == false %},{% endif %} 
						{% endfor %}
					</div>
				{% endif %}
				<div class="postdate">
					{{ post.date | date: "%e %B, %Y"  }}
				</div>
				<div>
					{{ post.content }}
				</div>
				<br />
				<a href="{{ post.url}}#disqus_thread">Comments</a>
			</div>
		</li>
    {% endfor %}
</ul>

<h3>OLDER</h3>
<ul class="postArchive">
{% for post in site.posts offset:5 %}
	<li>
		<span class="olderpostdate"> {{ post.date | date: "%d %b"  }} </span> <a class="postlink" href="{{ post.url }}">{{ post.title }}</a>
	</li>
{% endfor %}
</ul>

<script type="text/javascript">
//<![CDATA[
(function() {
    var links = document.getElementsByTagName('a');
    var query = '?';
    for(var i = 0; i < links.length; i++) {
    if(links[i].href.indexOf('#disqus_thread') >= 0) {
        query += 'url' + i + '=' + encodeURIComponent(links[i].href) + '&';
    }
    }
    document.write('<script charset="utf-8" type="text/javascript" src="http://disqus.com/forums/mrmdavidson/get_num_replies.js' + query + '"></' + 'script>');
})();
//]]>
</script>